using Masafet_Elseka.Application.Collection;
using Masafet_Elseka.Application.Common.Pagination;
using Masafet_Elseka.Application.DTOs.Collection;
using Masafet_Elseka.Application.Interfaces.ICollectionService;
using Masafet_Elseka.Application.Interfaces.IDriverFinanceService;
using Masafet_Elseka.Application.Interfaces.INotificationService;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Serilog;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace Masafet_Elseka.Infrastructure.Services.CollectionService
{
    // Daily captain collection by wallet transfer.
    //
    //  * Every evening (NoticeHour) captains owing more than the tolerance are told to
    //    transfer; an hour before the deadline they're reminded; at the deadline anyone
    //    still above the tolerance gets CollectionLockedAt and is taken offline.
    //  * The captain transfers to a company wallet and files a request (sender number +
    //    amount). The company phone relays the wallet's receipt SMS. A request and an SMS
    //    with the same sender number and amount are matched, the ledger is credited from
    //    the SMS amount, and the lock lifts by itself.
    //  * Anything that doesn't line up exactly (different amount, two captains claiming
    //    the same transfer, unreadable SMS, money nobody claimed) waits for an admin.
    //
    // Matching runs under one SQL app lock, so an SMS and a request arriving at the same
    // moment can never both match something else or be credited twice; the ledger's
    // unique WalletSmsId index is the last line of defence.
    public class CollectionService : ICollectionService
    {
        // A request and its SMS must be this close in time.
        public static readonly TimeSpan MatchWindow = TimeSpan.FromHours(6);
        // An expired request can still be confirmed by an SMS this late.
        public static readonly TimeSpan LateWindow = TimeSpan.FromHours(48);
        // The collector phone counts as online if it reported in this recently.
        public static readonly TimeSpan DeviceOnlineWindow = TimeSpan.FromMinutes(10);
        // Without a heartbeat for this long at the deadline, nobody is locked: we can't
        // tell who paid.
        public static readonly TimeSpan DeviceLockGuard = TimeSpan.FromMinutes(30);
        private static readonly TimeSpan PairingCodeLife = TimeSpan.FromMinutes(30);
        private const int HeartbeatSeconds = 60;
        private const int LookbackHours = 48;
        private const int MaxBatch = 100;

        private readonly Context _context;
        private readonly IDriverFinanceService _finance;
        private readonly INotificationService _notifications;

        public CollectionService(Context context, IDriverFinanceService finance, INotificationService notifications)
        {
            _context = context;
            _finance = finance;
            _notifications = notifications;
        }

        private static DateTime Now => DateTime.Now.ToEgyptTime();
        private static string? Clip(string? v, int max) =>
            string.IsNullOrWhiteSpace(v) ? null : v.Trim().Length > max ? v.Trim()[..max] : v.Trim();
        private static decimal Money(decimal v) => Math.Round(v, 2, MidpointRounding.AwayFromZero);

        // Amounts match on whole pounds: piasters are dropped on both sides so a
        // 0.xx difference between the request and the receipt never forces a
        // transfer into manual review.
        private static bool SameAmount(decimal a, decimal b) => Math.Floor(a) == Math.Floor(b);

        public static string ProviderLabel(WalletProvider? p) => p switch
        {
            WalletProvider.VodafoneCash => "فودافون كاش",
            WalletProvider.EtisalatCash => "اتصالات كاش",
            WalletProvider.InstaPay => "انستاباي",
            _ => "محفظة"
        };

        private async Task<PricingRule> GetRuleAsync() =>
            await _context.PricingRules.AsNoTracking().OrderBy(r => r.Id).FirstOrDefaultAsync() ?? new PricingRule();

        // The round in progress at `now`: it starts at the evening notice and its deadline
        // is DeadlineHour on the same day when that comes later, otherwise the next day.
        public static (DateTime CycleDate, DateTime NoticeAt, DateTime DeadlineAt) CurrentCycle(DateTime now, int noticeHour, int deadlineHour)
        {
            var date = now.Hour >= noticeHour ? now.Date : now.Date.AddDays(-1);
            var notice = date.AddHours(noticeHour);
            var deadline = (deadlineHour > noticeHour ? date : date.AddDays(1)).AddHours(deadlineHour);
            return (date, notice, deadline);
        }

        private static string DeadlineLabel(DateTime deadline) => deadline.Hour switch
        {
            0 => "12 بالليل",
            12 => "12 الضهر",
            < 12 => $"{deadline.Hour} الصبح",
            _ => $"{deadline.Hour - 12} بالليل"
        };

        private IQueryable<string> DriverIds() =>
            from ur in _context.UserRoles
            join r in _context.Roles on ur.RoleId equals r.Id
            where r.Name == "Driver"
            select ur.UserId;

        private async Task<bool> IsDriverAsync(string driverId) => await DriverIds().AnyAsync(id => id == driverId);

        private async Task<Dictionary<string, decimal>> DriversOwingAsync(decimal tolerance)
        {
            var drivers = DriverIds();
            return await _context.DriverLedgerEntries
                .Where(e => drivers.Contains(e.DriverId))
                .GroupBy(e => e.DriverId)
                .Select(g => new { DriverId = g.Key, Balance = g.Sum(e => e.Amount) })
                .Where(x => -x.Balance > tolerance)
                .ToDictionaryAsync(x => x.DriverId, x => -x.Balance);
        }

        private async Task SafeNotifyAsync(string userId, string title, string body, string type)
        {
            try
            {
                await _notifications.SendNotificationToUserWithSavingAsync(userId, title, body,
                    new Dictionary<string, string> { { "type", type } });
            }
            catch (Exception ex)
            {
                Log.Warning(ex, "Collection notification {Type} failed for {UserId}", type, userId);
            }
        }

        private async Task NotifyAdminsAsync(string title, string body, string type)
        {
            try
            {
                var adminIds = await (from u in _context.Users
                                      join ur in _context.UserRoles on u.Id equals ur.UserId
                                      join r in _context.Roles on ur.RoleId equals r.Id
                                      where r.Name == "Admin" || r.Name == "Accountant"
                                      select u.Id).Distinct().ToListAsync();
                foreach (var id in adminIds)
                    await SafeNotifyAsync(id, title, body, type);
            }
            catch (Exception ex)
            {
                Log.Warning(ex, "Admin collection notification failed");
            }
        }

        #region Matching

        private sealed record Credit(string DriverId, decimal Before, decimal After, decimal Amount);

        // Runs `work` in a transaction holding the global matching lock. The change
        // tracker is cleared first so every decision is made on fresh rows.
        private async Task<List<Credit>> InMatchLockAsync(Func<List<Credit>, Task> work)
        {
            var credits = new List<Credit>();
            _context.ChangeTracker.Clear();
            await using var tx = await _context.Database.BeginTransactionAsync();
            await _context.Database.ExecuteSqlRawAsync(
                "DECLARE @r int; EXEC @r = sp_getapplock @Resource = 'wallet-collection-match', @LockMode = 'Exclusive', " +
                "@LockOwner = 'Transaction', @LockTimeout = 15000; IF @r < 0 THROW 51001, 'collection match lock timeout', 1;");
            try
            {
                await work(credits);
                await tx.CommitAsync();
            }
            catch
            {
                _context.ChangeTracker.Clear();
                throw;
            }
            return credits;
        }

        private async Task AfterCreditsAsync(IEnumerable<Credit> credits)
        {
            foreach (var c in credits)
            {
                try { await _finance.AfterWalletCollectionAsync(c.DriverId, c.Before, c.After, c.Amount); }
                catch (Exception ex) { Log.Error(ex, "After-collection follow-up failed for {DriverId}", c.DriverId); }
            }
        }

        private async Task ConfirmAsync(CollectionRequest request, WalletSms sms, List<Credit> credits,
            WalletSmsMatchStatus smsStatus = WalletSmsMatchStatus.Matched, string? actorUserId = null, string? note = null)
        {
            var now = Now;
            var late = request.Status == CollectionRequestStatus.Expired;
            request.Status = CollectionRequestStatus.Confirmed;
            request.WalletSmsId = sms.Id;
            request.ResolvedAt = now;
            request.ResolvedByUserId = actorUserId;
            if (late) request.Note = "اتأكد بعد ما الطلب كان انتهى (الرسالة اتأخرت)";
            if (note != null) request.Note = note;

            sms.MatchStatus = smsStatus;
            sms.CollectionRequestId = request.Id;
            sms.DriverId = request.DriverId;
            if (actorUserId != null) { sms.ReviewedByUserId = actorUserId; sms.ReviewedAt = now; sms.Note = note ?? sms.Note; }
            await _context.SaveChangesAsync();

            await PostAsync(request.DriverId, sms, actorUserId, credits);
        }

        private static string? SenderLabel(WalletSms s) => s.CounterpartyPhone ?? s.CounterpartyAccount ?? s.CounterpartyName;
        private static string SenderLabel(CollectionRequest r) => r.SenderPhone ?? r.SenderAccount ?? r.SenderName ?? "—";

        private async Task PostAsync(string driverId, WalletSms sms, string? actorUserId, List<Credit> credits)
        {
            var description = $"تحويل {ProviderLabel(sms.Provider)} من {SenderLabel(sms) ?? "مرسل غير معروف"}";
            var (before, after, posted) = await _finance.PostWalletCollectionAsync(
                driverId, sms.Id, sms.Amount!.Value, description, sms.TxnRef, actorUserId);
            if (posted) credits.Add(new Credit(driverId, before, after, sms.Amount.Value));
        }

        // How well a receipt's sender fits what the captain wrote.
        public enum SenderFit { Unknown, Strong, Conflict }

        public static SenderFit CompareSender(WalletSms s, CollectionRequest r)
        {
            bool strong = false, conflict = false;
            if (s.CounterpartyPhone != null && r.SenderPhone != null)
            {
                if (s.CounterpartyPhone == r.SenderPhone) strong = true; else conflict = true;
            }
            if (s.CounterpartyAccount != null && r.SenderAccount != null)
            {
                if (string.Equals(s.CounterpartyAccount, r.SenderAccount, StringComparison.OrdinalIgnoreCase)) strong = true; else conflict = true;
            }
            switch (WalletSmsParser.NamesMatch(s.CounterpartyName, r.SenderName))
            {
                case true: strong = true; break;
                case false: conflict = true; break;
            }
            return strong ? SenderFit.Strong : conflict ? SenderFit.Conflict : SenderFit.Unknown;
        }

        private static void MarkAmbiguous(WalletSms sms, IEnumerable<CollectionRequest> requests, string why)
        {
            sms.MatchStatus = WalletSmsMatchStatus.NeedsReview;
            sms.Note = why;
            foreach (var r in requests.Where(r => r.Status == CollectionRequestStatus.Pending))
            {
                r.Status = CollectionRequestStatus.NeedsReview;
                r.Note = "بيتراجع: " + why;
            }
        }

        private static void MarkMismatch(WalletSms sms, CollectionRequest r)
        {
            sms.MatchStatus = WalletSmsMatchStatus.NeedsReview;
            sms.CollectionRequestId = r.Id;
            sms.Note = $"المبلغ في الرسالة {sms.Amount:0.##} ج.م والكابتن كاتب {r.Amount:0.##} ج.م";
            r.Status = CollectionRequestStatus.NeedsReview;
            r.Note = $"المبلغ اللي وصل {sms.Amount:0.##} ج.م مختلف عن المكتوب {r.Amount:0.##} ج.م — الإدارة هتراجع";
        }

        // The same InstaPay transfer often arrives twice: as the app push and as the bank
        // SMS. Keep the first, park the second.
        private async Task<bool> IsTwinAsync(WalletSms sms)
        {
            if (sms.CounterpartyPhone != null && sms.Provider != WalletProvider.InstaPay) return false;
            var from = sms.ReceivedAt.AddMinutes(-10);
            var to = sms.ReceivedAt.AddMinutes(10);
            var twins = await _context.WalletSms.AsNoTracking()
                .Where(x => x.Id != sms.Id && x.Kind == WalletSmsKind.Incoming && x.Source != sms.Source
                            && x.Amount == sms.Amount && x.ReceivedAt >= from && x.ReceivedAt <= to
                            && x.MatchStatus != WalletSmsMatchStatus.Dismissed)
                .ToListAsync();
            return twins.Any(x =>
                (x.CounterpartyAccount == null || sms.CounterpartyAccount == null || x.CounterpartyAccount == sms.CounterpartyAccount)
                && WalletSmsParser.NamesMatch(x.CounterpartyName, sms.CounterpartyName) != false
                && (x.CounterpartyPhone == null || sms.CounterpartyPhone == null || x.CounterpartyPhone == sms.CounterpartyPhone));
        }

        // A new receipt looks for the request it settles.
        //  1. It carries the sender phone (mobile wallets): match requests from that number.
        //  2. Otherwise (InstaPay: address / name, or nothing): same amount, in time, on
        //     the same wallet, and the sender must not contradict what the captain wrote.
        //     One captain fits -> confirmed; several -> review.
        private async Task MatchSmsAsync(long smsId, List<Credit> credits)
        {
            var sms = await _context.WalletSms.FirstOrDefaultAsync(s => s.Id == smsId);
            if (sms == null || sms.Kind != WalletSmsKind.Incoming || sms.MatchStatus != WalletSmsMatchStatus.Unclaimed
                || sms.Amount == null)
                return;

            if (await IsTwinAsync(sms))
            {
                sms.MatchStatus = WalletSmsMatchStatus.Dismissed;
                sms.Note = "نفس التحويل وصل مرتين (إشعار ورسالة)، اتحسب مرة واحدة";
                await _context.SaveChangesAsync();
                return;
            }

            var from = sms.ReceivedAt - LateWindow;
            var to = sms.ReceivedAt + MatchWindow;
            var open = _context.CollectionRequests.Include(r => r.Wallet)
                .Where(r => (r.Status == CollectionRequestStatus.Pending || r.Status == CollectionRequestStatus.Expired)
                            && r.CreatedAt >= from && r.CreatedAt <= to);
            // Expired requests only count for an exact late match.
            bool Live(CollectionRequest r) => r.Status == CollectionRequestStatus.Expired || r.CreatedAt >= sms.ReceivedAt - MatchWindow;

            if (sms.CounterpartyPhone != null)
            {
                var byPhone = (await open.Where(r => r.SenderPhone == sms.CounterpartyPhone)
                        .OrderBy(r => r.Status).ThenBy(r => r.CreatedAt).ToListAsync())
                    .Where(Live).ToList();
                if (byPhone.Count > 0)
                {
                    var exact = byPhone.Where(r => SameAmount(r.Amount, sms.Amount!.Value)).ToList();
                    if (exact.Count > 0 && exact.Select(r => r.DriverId).Distinct().Count() == 1)
                        await ConfirmAsync(exact[0], sms, credits);
                    else if (exact.Count > 1)
                        MarkAmbiguous(sms, exact, "أكتر من كابتن كاتب نفس رقم التحويل ونفس المبلغ");
                    else if (byPhone.Any(r => r.Status == CollectionRequestStatus.Pending))
                        MarkMismatch(sms, byPhone.Last(r => r.Status == CollectionRequestStatus.Pending));
                    await _context.SaveChangesAsync();
                    return;
                }
                // A phone nobody wrote: only an InstaPay-style receipt (address / name) can go on.
                if (sms.CounterpartyAccount == null && sms.CounterpartyName == null) return;
            }

            var sameWallet = sms.WalletId != null
                ? open.Where(r => r.WalletId == sms.WalletId)
                : sms.Provider != null ? open.Where(r => r.Wallet.Provider == sms.Provider) : open;
            var scored = (await sameWallet.OrderBy(r => r.Status).ThenBy(r => r.CreatedAt).ToListAsync())
                .Where(Live)
                .Select(r => (Request: r, Fit: CompareSender(sms, r)))
                .Where(x => x.Fit != SenderFit.Conflict)
                .ToList();
            var exactFit = scored.Where(x => SameAmount(x.Request.Amount, sms.Amount!.Value)).ToList();
            var strong = exactFit.Where(x => x.Fit == SenderFit.Strong).Select(x => x.Request).ToList();

            if (strong.Count > 0)
            {
                if (strong.Select(r => r.DriverId).Distinct().Count() == 1)
                    await ConfirmAsync(strong[0], sms, credits);
                else
                    MarkAmbiguous(sms, strong, "أكتر من كابتن بنفس المبلغ ونفس بيانات المرسل");
                await _context.SaveChangesAsync();
                return;
            }

            var strongOtherAmount = scored
                .Where(x => x.Fit == SenderFit.Strong && x.Request.Status == CollectionRequestStatus.Pending)
                .Select(x => x.Request).LastOrDefault();
            if (strongOtherAmount != null)
            {
                MarkMismatch(sms, strongOtherAmount);
                await _context.SaveChangesAsync();
                return;
            }

            // Nothing on the receipt identifies a captain: the amount alone decides, but
            // only when exactly one captain is waiting for it.
            if (sms.CounterpartyPhone != null) return;
            var unknown = exactFit.Select(x => x.Request).ToList();
            if (unknown.Count == 0) return;
            if (unknown.Select(r => r.DriverId).Distinct().Count() == 1)
                await ConfirmAsync(unknown[0], sms, credits,
                    note: "اتأكد بالمبلغ والوقت (الإشعار مفيهوش بيانات تطابق المرسل)");
            else
                MarkAmbiguous(sms, unknown, "أكتر من كابتن مستني نفس المبلغ والإشعار مفيهوش بيانات المرسل");
            await _context.SaveChangesAsync();
        }

        // A new request looks for a receipt that already arrived.
        private async Task MatchRequestAsync(long requestId, List<Credit> credits)
        {
            var request = await _context.CollectionRequests.FirstOrDefaultAsync(r => r.Id == requestId);
            if (request == null || request.Status != CollectionRequestStatus.Pending) return;

            var from = request.CreatedAt - MatchWindow;
            var to = request.CreatedAt + MatchWindow;
            var waiting = _context.WalletSms
                .Where(s => s.Kind == WalletSmsKind.Incoming && s.MatchStatus == WalletSmsMatchStatus.Unclaimed
                            && s.ReceivedAt >= from && s.ReceivedAt <= to);

            if (request.SenderPhone != null)
            {
                var smsList = await waiting.Where(s => s.CounterpartyPhone == request.SenderPhone)
                    .OrderBy(s => s.ReceivedAt).ToListAsync();
                if (smsList.Count > 0)
                {
                    var exact = smsList.FirstOrDefault(s => s.Amount != null && SameAmount(s.Amount.Value, request.Amount));
                    // Another captain may claim the same transfer at the same time; the
                    // global lock makes the first one win and the second stays pending.
                    if (exact != null) await ConfirmAsync(request, exact, credits);
                    else MarkMismatch(smsList[^1], request);
                    await _context.SaveChangesAsync();
                    return;
                }
            }

            // Receipts without a usable phone: let each one pick its request (it weighs
            // every open request, this one included) until this request is settled.
            var candidates = await waiting
                .Where(s => s.CounterpartyPhone == null || s.CounterpartyAccount != null || s.CounterpartyName != null)
                .OrderBy(s => s.ReceivedAt).Select(s => s.Id).Take(50).ToListAsync();
            foreach (var smsId in candidates)
            {
                await MatchSmsAsync(smsId, credits);
                if (request.Status != CollectionRequestStatus.Pending) break;
            }
        }

        #endregion

        #region Captain

        private async Task<List<CollectionRequestDTO>> RequestDtosAsync(IQueryable<CollectionRequest> query) =>
            await query.Select(r => new CollectionRequestDTO
            {
                Id = r.Id,
                WalletId = r.WalletId,
                WalletPhone = r.Wallet.PhoneNumber,
                Provider = r.Wallet.Provider.ToString(),
                SenderPhone = r.SenderPhone,
                SenderAccount = r.SenderAccount,
                SenderName = r.SenderName,
                Amount = r.Amount,
                Status = r.Status.ToString(),
                Note = r.Note,
                ReceivedAmount = _context.WalletSms.Where(s => s.Id == r.WalletSmsId).Select(s => s.Amount).FirstOrDefault(),
                CreatedAt = r.CreatedAt,
                ResolvedAt = r.ResolvedAt,
            }).ToListAsync();

        private async Task<List<CollectionWalletDTO>> CaptainWalletsAsync()
        {
            var onlineSince = Now - DeviceOnlineWindow;
            var wallets = await _context.CollectionWallets.AsNoTracking()
                .Where(w => w.IsActive)
                .OrderBy(w => w.SortOrder).ThenBy(w => w.Id)
                .Select(w => new CollectionWalletDTO
                {
                    Id = w.Id,
                    Provider = w.Provider.ToString(),
                    PhoneNumber = w.PhoneNumber,
                    HolderName = w.HolderName,
                    BankName = w.BankName,
                    IsOnline = w.Device != null && w.Device.IsActive && w.Device.LastSeenAt >= onlineSince,
                })
                .ToListAsync();
            foreach (var w in wallets) w.ProviderLabel = ProviderLabel(Enum.Parse<WalletProvider>(w.Provider));
            return wallets;
        }

        public async Task<Response<MyCollectionDTO>> GetMyCollectionAsync(string driverId)
        {
            var user = await _context.Users.AsNoTracking()
                .Where(u => u.Id == driverId)
                .Select(u => new { u.CollectionLockedAt, u.PhoneNumber, u.PayoutMethod, u.PayoutAccount, u.PayoutAccountName, u.FullName })
                .FirstOrDefaultAsync();
            if (user == null) return Response<MyCollectionDTO>.Failure("الكابتن غير موجود", 404);

            var rule = await GetRuleAsync();
            var balance = await _finance.GetBalanceAsync(driverId);
            var owed = balance < 0 ? -balance : 0;
            var now = Now;
            var (_, notice, deadline) = CurrentCycle(now, rule.CollectionNoticeHour, rule.CollectionDeadlineHour);
            var inWindow = now >= notice && now < deadline;
            var nextDeadline = now < deadline ? deadline : deadline.AddDays(1);

            var recent = await RequestDtosAsync(_context.CollectionRequests.AsNoTracking()
                .Where(r => r.DriverId == driverId).OrderByDescending(r => r.Id).Take(10));
            var pending = recent.FirstOrDefault(r => r.Status is nameof(CollectionRequestStatus.Pending) or nameof(CollectionRequestStatus.NeedsReview));

            // Pre-fill the form with what he used last, or his payout account.
            var lastSender = recent.Select(r => r.SenderPhone).FirstOrDefault(p => p != null)
                ?? (user.PayoutMethod == PayoutMethod.MobileWallet ? user.PayoutAccount : null)
                ?? WalletSmsParser.NormalizePhone(user.PhoneNumber);
            var lastAccount = recent.Select(r => r.SenderAccount).FirstOrDefault(a => a != null)
                ?? (user.PayoutMethod == PayoutMethod.InstaPay ? WalletSmsParser.NormalizeInstaPayAddress(user.PayoutAccount) : null);
            var lastName = recent.Select(r => r.SenderName).FirstOrDefault(n => n != null)
                ?? user.PayoutAccountName ?? user.FullName;

            return Response<MyCollectionDTO>.Success(new MyCollectionDTO
            {
                Enabled = rule.CollectionEnabled,
                OwedToCompany = owed,
                Tolerance = rule.CollectionTolerance,
                MustPay = owed > rule.CollectionTolerance,
                NoticeHour = rule.CollectionNoticeHour,
                DeadlineHour = rule.CollectionDeadlineHour,
                DeadlineAt = nextDeadline,
                InWindow = inWindow,
                IsLocked = rule.CollectionEnabled && user.CollectionLockedAt != null && owed > rule.CollectionTolerance,
                LockedSince = user.CollectionLockedAt,
                Wallets = await CaptainWalletsAsync(),
                Pending = pending,
                Recent = recent,
                LastSenderPhone = lastSender,
                LastSenderAccount = lastAccount,
                LastSenderName = lastName,
                ServerTime = now,
            }, "", 200);
        }

        public async Task<Response<CollectionRequestDTO>> CreateRequestAsync(string driverId, CreateCollectionRequestDTO dto)
        {
            var rule = await GetRuleAsync();
            if (!rule.CollectionEnabled)
                return Response<CollectionRequestDTO>.Failure("التحصيل عن طريق المحفظة مش مفعّل حالياً", 400);

            var wallet = await _context.CollectionWallets.AsNoTracking().FirstOrDefaultAsync(w => w.Id == dto.WalletId && w.IsActive);
            if (wallet == null)
                return Response<CollectionRequestDTO>.Failure("اختار المحفظة اللي حوّلت عليها", 400);

            var instaPay = wallet.Provider == WalletProvider.InstaPay;
            var sender = WalletSmsParser.NormalizePhone(dto.SenderPhone);
            var account = WalletSmsParser.NormalizeInstaPayAddress(dto.SenderAccount);
            var senderName = string.IsNullOrWhiteSpace(dto.SenderName) ? null : dto.SenderName.Trim();
            if (senderName != null && (senderName.Length < 3 || senderName.Length > 100))
                return Response<CollectionRequestDTO>.Failure("اكتب اسمك زي ما بيظهر في التحويل", 400);
            if (!string.IsNullOrWhiteSpace(dto.SenderPhone) && sender == null)
                return Response<CollectionRequestDTO>.Failure("رقم الموبايل لازم يكون رقم مصري 11 رقم", 400);
            if (!string.IsNullOrWhiteSpace(dto.SenderAccount) && account == null)
                return Response<CollectionRequestDTO>.Failure("عنوان انستاباي لازم يكون بالشكل name@instapay", 400);
            if (instaPay)
            {
                // Receipts name the sender by address and / or name, rarely by number.
                if (account == null && sender == null)
                    return Response<CollectionRequestDTO>.Failure("اكتب عنوان انستاباي أو رقم الموبايل اللي حوّلت منه", 400);
                if (senderName == null)
                    return Response<CollectionRequestDTO>.Failure("اكتب اسمك زي ما بيظهر في انستاباي", 400);
                if (account == wallet.PhoneNumber)
                    return Response<CollectionRequestDTO>.Failure("اكتب العنوان اللي حوّلت منه، مش عنوان الشركة", 400);
            }
            else
            {
                if (sender == null)
                    return Response<CollectionRequestDTO>.Failure("اكتب رقم المحفظة اللي حوّلت منها (رقم موبايل مصري 11 رقم)", 400);
                if (sender == wallet.PhoneNumber)
                    return Response<CollectionRequestDTO>.Failure("اكتب الرقم اللي حوّلت منه، مش رقم محفظة الشركة", 400);
            }

            // Collect in whole pounds: drop the piasters so the receipt SMS matches
            // on a clean number. The small residual stays on the ledger, well under
            // the collection tolerance.
            var amount = Math.Floor(Money(dto.Amount));
            if (amount < 1 || amount > 100_000)
                return Response<CollectionRequestDTO>.Failure("مفيش مبلغ مطلوب تحويله", 400);

            var balance = await _finance.GetBalanceAsync(driverId);
            if (balance >= 0)
                return Response<CollectionRequestDTO>.Failure("مفيش مستحقات عليك للشركة حالياً", 400);

            var now = Now;
            // A double tap / retry returns the request already filed.
            var since = now.AddMinutes(-10);
            var duplicate = (await RequestDtosAsync(_context.CollectionRequests.AsNoTracking()
                .Where(r => r.DriverId == driverId && r.WalletId == wallet.Id && r.SenderPhone == sender
                            && r.SenderAccount == account && r.Amount == amount
                            && r.Status == CollectionRequestStatus.Pending && r.CreatedAt >= since)
                .OrderByDescending(r => r.Id).Take(1))).FirstOrDefault();
            if (duplicate != null)
                return Response<CollectionRequestDTO>.Success(duplicate, "الطلب ده متسجّل بالفعل", 200);

            var openCount = await _context.CollectionRequests.CountAsync(r => r.DriverId == driverId
                && (r.Status == CollectionRequestStatus.Pending || r.Status == CollectionRequestStatus.NeedsReview));
            if (openCount >= 3)
                return Response<CollectionRequestDTO>.Failure("عندك طلبات لسه بتتراجع، استنى تأكيدها أو كلّم الدعم", 400);

            var request = new CollectionRequest
            {
                DriverId = driverId,
                WalletId = wallet.Id,
                SenderPhone = sender,
                SenderAccount = account,
                SenderName = senderName,
                Amount = amount,
                DebtAtRequest = -balance,
                Status = CollectionRequestStatus.Pending,
                CreatedAt = now,
            };
            _context.CollectionRequests.Add(request);
            await _context.SaveChangesAsync();

            try
            {
                var credits = await InMatchLockAsync(c => MatchRequestAsync(request.Id, c));
                await AfterCreditsAsync(credits);
            }
            catch (Exception ex)
            {
                // The request is saved; the next SMS or the sweeper will match it.
                Log.Error(ex, "Matching collection request {RequestId} failed", request.Id);
            }

            var saved = (await RequestDtosAsync(_context.CollectionRequests.AsNoTracking().Where(r => r.Id == request.Id))).First();
            var message = saved.Status switch
            {
                nameof(CollectionRequestStatus.Confirmed) => "تم تأكيد التحويل ✅",
                nameof(CollectionRequestStatus.NeedsReview) => "المبلغ اللي وصل مختلف عن المكتوب، الإدارة هتراجع",
                _ => "تم تسجيل الطلب، هيتأكد أول ما رسالة الاستلام توصل"
            };
            return Response<CollectionRequestDTO>.Success(saved, message, 201);
        }

        public async Task<Response<CollectionRequestDTO>> CancelRequestAsync(string driverId, long requestId)
        {
            var updated = await _context.CollectionRequests
                .Where(r => r.Id == requestId && r.DriverId == driverId && r.Status == CollectionRequestStatus.Pending)
                .ExecuteUpdateAsync(s => s
                    .SetProperty(r => r.Status, CollectionRequestStatus.Cancelled)
                    .SetProperty(r => r.ResolvedAt, Now)
                    .SetProperty(r => r.Note, "الكابتن لغى الطلب"));
            if (updated == 0)
                return Response<CollectionRequestDTO>.Failure("الطلب مش موجود أو اتراجع بالفعل", 400);
            var dto = (await RequestDtosAsync(_context.CollectionRequests.AsNoTracking().Where(r => r.Id == requestId))).First();
            return Response<CollectionRequestDTO>.Success(dto, "تم إلغاء الطلب", 200);
        }

        #endregion

        #region Collector phone

        private static string Sha256Hex(string value) =>
            Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value))).ToLowerInvariant();

        private static string NewPairingCode()
        {
            const string alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
            Span<char> code = stackalloc char[8];
            for (var i = 0; i < code.Length; i++) code[i] = alphabet[RandomNumberGenerator.GetInt32(alphabet.Length)];
            return new string(code);
        }

        public async Task<Response<CollectorPairResultDTO>> PairDeviceAsync(CollectorPairDTO dto)
        {
            var code = (dto.Code ?? string.Empty).Trim().Replace(" ", "").Replace("-", "").ToUpperInvariant();
            var now = Now;
            var device = code.Length < 6 ? null : await _context.CollectorDevices
                .FirstOrDefaultAsync(d => d.PairingCode == code && d.IsActive && d.PairingExpiresAt > now);
            if (device == null)
                return Response<CollectorPairResultDTO>.Failure("كود الربط غلط أو انتهى. اطلب كود جديد من لوحة التحكم", 400);

            var key = $"{device.Id:N}.{Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)).TrimEnd('=').Replace('+', '-').Replace('/', '_')}";
            device.KeyHash = Sha256Hex(key);
            device.PairingCode = null;
            device.PairingExpiresAt = null;
            device.PairedAt = now;
            device.LastSeenAt = now;
            device.AppVersion = dto.AppVersion?.Trim() is { Length: > 0 } v ? v[..Math.Min(40, v.Length)] : device.AppVersion;
            await _context.SaveChangesAsync();

            Log.Information("Collector device {DeviceId} ({Name}) paired", device.Id, device.Name);
            return Response<CollectorPairResultDTO>.Success(
                new CollectorPairResultDTO { DeviceId = device.Id, DeviceKey = key, Name = device.Name }, "تم الربط", 200);
        }

        public async Task<CollectorDevice?> AuthenticateDeviceAsync(string? deviceKey)
        {
            if (string.IsNullOrWhiteSpace(deviceKey)) return null;
            var dot = deviceKey.IndexOf('.');
            if (dot <= 0 || !Guid.TryParseExact(deviceKey[..dot], "N", out var id)) return null;

            var device = await _context.CollectorDevices.FirstOrDefaultAsync(d => d.Id == id);
            if (device == null || !device.IsActive || device.KeyHash == null) return null;

            var expected = Encoding.ASCII.GetBytes(device.KeyHash);
            var actual = Encoding.ASCII.GetBytes(Sha256Hex(deviceKey));
            return CryptographicOperations.FixedTimeEquals(expected, actual) ? device : null;
        }

        private async Task<CollectorConfigDTO> ConfigAsync(CollectorDevice device) => new()
        {
            DeviceName = device.Name,
            ServerTime = Now,
            SenderHints = WalletSmsParser.SenderHints.ToList(),
            InstaPayKeywords = WalletSmsParser.InstaPayKeywords.ToList(),
            NotificationPackages = WalletSmsParser.NotificationPackages.ToList(),
            Wallets = await _context.CollectionWallets.AsNoTracking()
                .Where(w => w.DeviceId == device.Id)
                .Select(w => new CollectorWalletDTO { Id = w.Id, Provider = w.Provider.ToString(), PhoneNumber = w.PhoneNumber })
                .ToListAsync(),
            LookbackHours = LookbackHours,
            HeartbeatSeconds = HeartbeatSeconds,
        };

        public async Task<CollectorConfigDTO> HeartbeatAsync(CollectorDevice device, CollectorHeartbeatDTO dto)
        {
            var status = JsonSerializer.Serialize(new
            {
                dto.Battery, dto.Charging, dto.SmsPermission, dto.NotificationAccess, dto.Pending, dto.LastInboxId,
                LastError = dto.LastError?[..Math.Min(300, dto.LastError.Length)],
            });
            device.LastSeenAt = Now;
            if (!string.IsNullOrWhiteSpace(dto.AppVersion)) device.AppVersion = dto.AppVersion.Trim()[..Math.Min(40, dto.AppVersion.Trim().Length)];
            device.LastStatus = status.Length > 1000 ? status[..1000] : status;
            await _context.SaveChangesAsync();
            return await ConfigAsync(device);
        }

        public async Task<List<CollectorSmsResultDTO>> IngestSmsAsync(CollectorDevice device, CollectorSmsBatchDTO batch)
        {
            var results = new List<CollectorSmsResultDTO>();
            var wallets = await _context.CollectionWallets.AsNoTracking().ToListAsync();
            var ownNumbers = wallets.Select(w => w.PhoneNumber).ToList();
            var deviceId = device.Id;
            var now = Now;

            await _context.CollectorDevices.Where(d => d.Id == deviceId)
                .ExecuteUpdateAsync(s => s.SetProperty(d => d.LastSeenAt, now));

            foreach (var m in (batch.Messages ?? new()).Take(MaxBatch))
            {
                var clientId = (m.ClientId ?? string.Empty).Trim();
                if (clientId.Length == 0 || clientId.Length > 100 || string.IsNullOrWhiteSpace(m.Body))
                {
                    results.Add(new CollectorSmsResultDTO { ClientId = clientId, Status = "rejected" });
                    continue;
                }

                var existing = await _context.WalletSms.AsNoTracking()
                    .Where(s => s.DeviceId == deviceId && s.ClientId == clientId)
                    .Select(s => new { s.Id, s.Kind, s.MatchStatus })
                    .FirstOrDefaultAsync();
                if (existing != null)
                {
                    results.Add(new CollectorSmsResultDTO
                    {
                        ClientId = clientId, Status = "duplicate", Id = existing.Id,
                        Kind = existing.Kind.ToString(), MatchStatus = existing.MatchStatus.ToString(),
                    });
                    continue;
                }

                var sender = (m.Sender ?? string.Empty).Trim();
                if (sender.Length > 60) sender = sender[..60];
                var body = m.Body.Length > 2000 ? m.Body[..2000] : m.Body;

                // Phone clocks can be off; anything absurd falls back to the upload time.
                var receivedAt = now;
                if (m.ReceivedAtMs > 0)
                {
                    var t = DateTimeOffset.FromUnixTimeMilliseconds(m.ReceivedAtMs).UtcDateTime.ToEgyptTime();
                    if (t <= now.AddMinutes(10) && t >= now.AddDays(-30)) receivedAt = t;
                }

                var parsed = WalletSmsParser.Parse(sender, body, ownNumbers);
                // Ads, promotions, OTPs, balance-info and other non-money SMS on the
                // wallet line are not stored: only transfers and receipts belong in the
                // collection records. The collector acks "ignored" so it won't resend.
                if (parsed.Kind == WalletSmsKind.Ignored)
                {
                    results.Add(new CollectorSmsResultDTO { ClientId = clientId, Status = "ignored" });
                    continue;
                }
                if (parsed.TxnRef != null && parsed.Provider != null
                    && await _context.WalletSms.AnyAsync(s => s.Provider == parsed.Provider && s.TxnRef == parsed.TxnRef))
                {
                    // Same transfer already stored (another phone, reinstall, re-scan).
                    results.Add(new CollectorSmsResultDTO { ClientId = clientId, Status = "duplicate" });
                    continue;
                }
                var onDevice = wallets.Where(w => w.DeviceId == deviceId && (parsed.Provider == null || w.Provider == parsed.Provider)).ToList();
                var sms = new WalletSms
                {
                    DeviceId = deviceId,
                    ClientId = clientId,
                    Sender = sender,
                    Body = body,
                    ReceivedAt = receivedAt,
                    IngestedAt = now,
                    Source = string.Equals(m.Source, "notification", StringComparison.OrdinalIgnoreCase)
                        ? WalletSmsSource.Notification : WalletSmsSource.Sms,
                    SourcePackage = Clip(m.Package, 100),
                    Provider = parsed.Provider,
                    WalletId = onDevice.Count == 1 ? onDevice[0].Id : null,
                    Kind = parsed.Kind,
                    Amount = parsed.Amount,
                    CounterpartyPhone = parsed.CounterpartyPhone,
                    CounterpartyAccount = Clip(parsed.CounterpartyAccount, 100),
                    CounterpartyName = Clip(parsed.CounterpartyName, 100),
                    TxnRef = parsed.TxnRef,
                    BalanceAfter = parsed.BalanceAfter,
                    MatchStatus = parsed.Kind switch
                    {
                        WalletSmsKind.Incoming => WalletSmsMatchStatus.Unclaimed,
                        WalletSmsKind.Unparsed => WalletSmsMatchStatus.NeedsReview,
                        _ => WalletSmsMatchStatus.NotApplicable
                    },
                    Note = parsed.Kind == WalletSmsKind.Unparsed ? "شكلها رسالة تحويل بس المبلغ أو الرقم مش واضح" : null,
                };

                try
                {
                    _context.WalletSms.Add(sms);
                    await _context.SaveChangesAsync();
                }
                catch (DbUpdateException)
                {
                    // Same transfer reference already stored (another phone / reinstall).
                    _context.ChangeTracker.Clear();
                    results.Add(new CollectorSmsResultDTO { ClientId = clientId, Status = "duplicate" });
                    continue;
                }

                if (sms.WalletId != null)
                    await _context.CollectionWallets.Where(w => w.Id == sms.WalletId)
                        .ExecuteUpdateAsync(s => s.SetProperty(w => w.LastSmsAt, receivedAt));

                if (sms.Kind == WalletSmsKind.Incoming)
                {
                    try
                    {
                        var id = sms.Id;
                        var credits = await InMatchLockAsync(c => MatchSmsAsync(id, c));
                        await AfterCreditsAsync(credits);
                    }
                    catch (Exception ex)
                    {
                        // Stored and Unclaimed: the request side or an admin will pick it up.
                        Log.Error(ex, "Matching wallet SMS {SmsId} failed", sms.Id);
                    }
                }

                var final = await _context.WalletSms.AsNoTracking().Where(s => s.Id == sms.Id)
                    .Select(s => s.MatchStatus).FirstAsync();
                results.Add(new CollectorSmsResultDTO
                {
                    ClientId = clientId, Status = "stored", Id = sms.Id,
                    Kind = sms.Kind.ToString(), MatchStatus = final.ToString(),
                });
            }
            return results;
        }

        #endregion

        #region Admin

        public async Task<Response<CollectionOverviewDTO>> GetOverviewAsync()
        {
            var rule = await GetRuleAsync();
            var now = Now;
            var today = now.Date;
            var onlineSince = now - DeviceOnlineWindow;
            var owing = await DriversOwingAsync(rule.CollectionTolerance);
            var lockedIds = await _context.Users.Where(u => u.CollectionLockedAt != null).Select(u => u.Id).ToListAsync();
            var collectedToday = await _context.DriverLedgerEntries
                .Where(e => e.Type == LedgerEntryType.WalletCollection && e.CreatedAt >= today)
                .Select(e => e.Amount).ToListAsync();

            var cycles = await _context.CollectionCycles.AsNoTracking()
                .OrderByDescending(c => c.CycleDate).Take(7)
                .Select(c => new CollectionCycleDTO
                {
                    CycleDate = c.CycleDate,
                    NoticeSentAt = c.NoticeSentAt,
                    NoticeCount = c.NoticeCount,
                    ReminderSentAt = c.ReminderSentAt,
                    ReminderCount = c.ReminderCount,
                    LockAppliedAt = c.LockAppliedAt,
                    LockedCount = c.LockedCount,
                    LockNote = c.LockNote,
                }).ToListAsync();

            return Response<CollectionOverviewDTO>.Success(new CollectionOverviewDTO
            {
                Enabled = rule.CollectionEnabled,
                Tolerance = rule.CollectionTolerance,
                NoticeHour = rule.CollectionNoticeHour,
                DeadlineHour = rule.CollectionDeadlineHour,
                PendingRequests = await _context.CollectionRequests.CountAsync(r => r.Status == CollectionRequestStatus.Pending),
                ReviewRequests = await _context.CollectionRequests.CountAsync(r => r.Status == CollectionRequestStatus.NeedsReview || r.Status == CollectionRequestStatus.Expired),
                UnclaimedSms = await _context.WalletSms.CountAsync(s => s.MatchStatus == WalletSmsMatchStatus.Unclaimed),
                ReviewSms = await _context.WalletSms.CountAsync(s => s.MatchStatus == WalletSmsMatchStatus.NeedsReview),
                CollectedToday = collectedToday.Sum(),
                CollectedTodayCount = collectedToday.Count,
                LockedDrivers = rule.CollectionEnabled ? lockedIds.Count(owing.ContainsKey) : 0,
                MustPayDrivers = owing.Count,
                TotalDueAboveTolerance = owing.Values.Sum(),
                OnlineDevices = await _context.CollectorDevices.CountAsync(d => d.IsActive && d.LastSeenAt >= onlineSince),
                ActiveWallets = await _context.CollectionWallets.CountAsync(w => w.IsActive),
                RecentCycles = cycles,
            }, "", 200);
        }

        private IQueryable<AdminCollectionRequestDTO> AdminRequestQuery(IQueryable<CollectionRequest> q) =>
            q.Select(r => new AdminCollectionRequestDTO
            {
                Id = r.Id,
                WalletId = r.WalletId,
                WalletPhone = r.Wallet.PhoneNumber,
                Provider = r.Wallet.Provider.ToString(),
                SenderPhone = r.SenderPhone,
                SenderAccount = r.SenderAccount,
                SenderName = r.SenderName,
                Amount = r.Amount,
                Status = r.Status.ToString(),
                Note = r.Note,
                ReceivedAmount = _context.WalletSms.Where(s => s.Id == r.WalletSmsId).Select(s => s.Amount).FirstOrDefault(),
                CreatedAt = r.CreatedAt,
                ResolvedAt = r.ResolvedAt,
                DriverId = r.DriverId,
                DriverName = r.Driver.FullName,
                DriverPhone = r.Driver.PhoneNumber,
                DebtAtRequest = r.DebtAtRequest,
                WalletSmsId = r.WalletSmsId,
                ResolvedByName = r.ResolvedByUserId == null ? null
                    : _context.Users.IgnoreQueryFilters().Where(u => u.Id == r.ResolvedByUserId).Select(u => u.FullName).FirstOrDefault(),
            });

        // status: Pending | Confirmed | NeedsReview | Rejected | Expired | Cancelled | review (NeedsReview + Expired)
        public async Task<Response<PaginationPagedResponse<AdminCollectionRequestDTO>>> GetRequestsAsync(PaginationRequest pagination, string? status, string? search)
        {
            var page = Math.Max(1, pagination.PageNumber);
            var size = Math.Clamp(pagination.PageSize, 1, 100);
            var query = _context.CollectionRequests.AsNoTracking().AsQueryable();
            if (string.Equals(status, "review", StringComparison.OrdinalIgnoreCase))
                query = query.Where(r => r.Status == CollectionRequestStatus.NeedsReview || r.Status == CollectionRequestStatus.Expired);
            else if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<CollectionRequestStatus>(status, true, out var st))
                query = query.Where(r => r.Status == st);
            if (!string.IsNullOrWhiteSpace(search))
            {
                var s = search.Trim();
                query = query.Where(r => (r.SenderPhone != null && r.SenderPhone.Contains(s))
                                         || (r.SenderAccount != null && r.SenderAccount.Contains(s))
                                         || (r.SenderName != null && r.SenderName.Contains(s))
                                         || r.Driver.FullName.Contains(s)
                                         || (r.Driver.PhoneNumber != null && r.Driver.PhoneNumber.Contains(s)));
            }

            var total = await query.CountAsync();
            var items = await AdminRequestQuery(query.OrderByDescending(r => r.Id).Skip((page - 1) * size).Take(size)).ToListAsync();
            return Response<PaginationPagedResponse<AdminCollectionRequestDTO>>.Success(
                new PaginationPagedResponse<AdminCollectionRequestDTO>(items, total, page, size), "", 200);
        }

        private IQueryable<WalletSmsDTO> SmsQuery(IQueryable<WalletSms> q) =>
            q.Select(s => new WalletSmsDTO
            {
                Id = s.Id,
                DeviceName = s.Device != null ? s.Device.Name : null,
                Sender = s.Sender,
                Body = s.Body,
                ReceivedAt = s.ReceivedAt,
                IngestedAt = s.IngestedAt,
                Provider = s.Provider.HasValue ? s.Provider.Value.ToString() : null,
                WalletPhone = s.Wallet != null ? s.Wallet.PhoneNumber : null,
                Kind = s.Kind.ToString(),
                Amount = s.Amount,
                CounterpartyPhone = s.CounterpartyPhone,
                CounterpartyAccount = s.CounterpartyAccount,
                CounterpartyName = s.CounterpartyName,
                Source = s.Source.ToString(),
                SourcePackage = s.SourcePackage,
                TxnRef = s.TxnRef,
                BalanceAfter = s.BalanceAfter,
                MatchStatus = s.MatchStatus.ToString(),
                CollectionRequestId = s.CollectionRequestId,
                DriverId = s.DriverId,
                DriverName = s.DriverId == null ? null
                    : _context.Users.IgnoreQueryFilters().Where(u => u.Id == s.DriverId).Select(u => u.FullName).FirstOrDefault(),
                Note = s.Note,
                ReviewedByName = s.ReviewedByUserId == null ? null
                    : _context.Users.IgnoreQueryFilters().Where(u => u.Id == s.ReviewedByUserId).Select(u => u.FullName).FirstOrDefault(),
                ReviewedAt = s.ReviewedAt,
            });

        // status: Unclaimed | Matched | NeedsReview | Assigned | Dismissed | NotApplicable | open (Unclaimed + NeedsReview)
        public async Task<Response<PaginationPagedResponse<WalletSmsDTO>>> GetSmsAsync(PaginationRequest pagination, string? status, string? kind, string? search)
        {
            var page = Math.Max(1, pagination.PageNumber);
            var size = Math.Clamp(pagination.PageSize, 1, 100);
            var query = _context.WalletSms.AsNoTracking().AsQueryable();
            if (string.Equals(status, "open", StringComparison.OrdinalIgnoreCase))
                query = query.Where(s => s.MatchStatus == WalletSmsMatchStatus.Unclaimed || s.MatchStatus == WalletSmsMatchStatus.NeedsReview);
            else if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<WalletSmsMatchStatus>(status, true, out var st))
                query = query.Where(s => s.MatchStatus == st);
            if (!string.IsNullOrWhiteSpace(kind) && Enum.TryParse<WalletSmsKind>(kind, true, out var k))
                query = query.Where(s => s.Kind == k);
            if (!string.IsNullOrWhiteSpace(search))
            {
                var s = search.Trim();
                query = query.Where(x => (x.CounterpartyPhone != null && x.CounterpartyPhone.Contains(s))
                                         || (x.CounterpartyAccount != null && x.CounterpartyAccount.Contains(s))
                                         || (x.CounterpartyName != null && x.CounterpartyName.Contains(s))
                                         || (x.TxnRef != null && x.TxnRef.Contains(s)) || x.Body.Contains(s));
            }

            var total = await query.CountAsync();
            var items = await SmsQuery(query.OrderByDescending(s => s.Id).Skip((page - 1) * size).Take(size)).ToListAsync();
            return Response<PaginationPagedResponse<WalletSmsDTO>>.Success(
                new PaginationPagedResponse<WalletSmsDTO>(items, total, page, size), "", 200);
        }

        private async Task<WalletSmsDTO> SmsDtoAsync(long id) =>
            await SmsQuery(_context.WalletSms.AsNoTracking().Where(s => s.Id == id)).FirstAsync();

        public async Task<Response<WalletSmsDTO>> AssignSmsAsync(long smsId, AssignSmsDTO dto, string actorUserId)
        {
            string? error = null;
            string? driverId = null;
            var note = string.IsNullOrWhiteSpace(dto.Note) ? null : dto.Note.Trim()[..Math.Min(500, dto.Note.Trim().Length)];

            var credits = await InMatchLockAsync(async credits =>
            {
                var sms = await _context.WalletSms.FirstOrDefaultAsync(s => s.Id == smsId);
                if (sms == null) { error = "الرسالة مش موجودة"; return; }
                if (sms.MatchStatus is not (WalletSmsMatchStatus.Unclaimed or WalletSmsMatchStatus.NeedsReview))
                { error = "الرسالة دي اتراجعت بالفعل"; return; }
                if (sms.Amount is not > 0) { error = "الرسالة مفيهاش مبلغ واضح، سجّل المبلغ كتسوية يدوية للكابتن"; return; }

                if (dto.RequestId != null)
                {
                    var request = await _context.CollectionRequests.FirstOrDefaultAsync(r => r.Id == dto.RequestId);
                    if (request == null) { error = "الطلب مش موجود"; return; }
                    if (request.Status is not (CollectionRequestStatus.Pending or CollectionRequestStatus.NeedsReview or CollectionRequestStatus.Expired))
                    { error = "الطلب ده اتقفل بالفعل"; return; }
                    driverId = request.DriverId;
                    await ConfirmAsync(request, sms, credits, WalletSmsMatchStatus.Assigned, actorUserId,
                        note ?? (request.Amount != sms.Amount ? $"اتأكد يدوياً بمبلغ الرسالة {sms.Amount:0.##} ج.م" : "اتأكد يدوياً"));
                    return;
                }

                if (string.IsNullOrWhiteSpace(dto.DriverId) || !await IsDriverAsync(dto.DriverId))
                { error = "اختار الكابتن أو الطلب"; return; }
                driverId = dto.DriverId;

                // A request this SMS was already linked to (amount mismatch) is settled by it.
                if (sms.CollectionRequestId != null)
                {
                    var linked = await _context.CollectionRequests.FirstOrDefaultAsync(r => r.Id == sms.CollectionRequestId);
                    if (linked != null && linked.DriverId == driverId && linked.Status == CollectionRequestStatus.NeedsReview)
                    {
                        await ConfirmAsync(linked, sms, credits, WalletSmsMatchStatus.Assigned, actorUserId,
                            note ?? $"اتأكد يدوياً بمبلغ الرسالة {sms.Amount:0.##} ج.م");
                        return;
                    }
                }

                sms.MatchStatus = WalletSmsMatchStatus.Assigned;
                sms.DriverId = driverId;
                sms.ReviewedByUserId = actorUserId;
                sms.ReviewedAt = Now;
                sms.Note = note ?? "اتسجّل للكابتن يدوياً";
                await _context.SaveChangesAsync();
                await PostAsync(driverId, sms, actorUserId, credits);
            });

            if (error != null) return Response<WalletSmsDTO>.Failure(error, 400);
            await AfterCreditsAsync(credits);
            await _finance.WriteAuditAsync(actorUserId, "WalletSmsAssigned", driverId, $"sms={smsId} request={dto.RequestId} {note}");
            return Response<WalletSmsDTO>.Success(await SmsDtoAsync(smsId), "تم تسجيل التحويل للكابتن", 200);
        }

        public async Task<Response<WalletSmsDTO>> DismissSmsAsync(long smsId, ReviewNoteDTO dto, string actorUserId)
        {
            var note = (dto.Note ?? string.Empty).Trim();
            if (note.Length < 3) return Response<WalletSmsDTO>.Failure("اكتب سبب الاستبعاد", 400);
            note = note[..Math.Min(500, note.Length)];

            var updated = await _context.WalletSms
                .Where(s => s.Id == smsId && (s.MatchStatus == WalletSmsMatchStatus.Unclaimed || s.MatchStatus == WalletSmsMatchStatus.NeedsReview))
                .ExecuteUpdateAsync(s => s
                    .SetProperty(x => x.MatchStatus, WalletSmsMatchStatus.Dismissed)
                    .SetProperty(x => x.Note, note)
                    .SetProperty(x => x.ReviewedByUserId, actorUserId)
                    .SetProperty(x => x.ReviewedAt, Now));
            if (updated == 0) return Response<WalletSmsDTO>.Failure("الرسالة مش موجودة أو اتراجعت بالفعل", 400);

            await _finance.WriteAuditAsync(actorUserId, "WalletSmsDismissed", null, $"sms={smsId} {note}");
            return Response<WalletSmsDTO>.Success(await SmsDtoAsync(smsId), "تم الاستبعاد", 200);
        }

        public async Task<Response<AdminCollectionRequestDTO>> RejectRequestAsync(long requestId, ReviewNoteDTO dto, string actorUserId)
        {
            var note = (dto.Note ?? string.Empty).Trim();
            if (note.Length < 3) return Response<AdminCollectionRequestDTO>.Failure("اكتب سبب الرفض", 400);
            note = note[..Math.Min(500, note.Length)];

            var request = await _context.CollectionRequests.FirstOrDefaultAsync(r => r.Id == requestId);
            if (request == null) return Response<AdminCollectionRequestDTO>.Failure("الطلب مش موجود", 404);
            if (request.Status is not (CollectionRequestStatus.Pending or CollectionRequestStatus.NeedsReview or CollectionRequestStatus.Expired))
                return Response<AdminCollectionRequestDTO>.Failure("الطلب ده اتقفل بالفعل", 400);

            request.Status = CollectionRequestStatus.Rejected;
            request.Note = note;
            request.ResolvedAt = Now;
            request.ResolvedByUserId = actorUserId;
            // An SMS that was only parked on this request goes back to the unclaimed pile.
            await _context.WalletSms
                .Where(s => s.CollectionRequestId == requestId && s.MatchStatus == WalletSmsMatchStatus.NeedsReview)
                .ExecuteUpdateAsync(s => s
                    .SetProperty(x => x.MatchStatus, WalletSmsMatchStatus.Unclaimed)
                    .SetProperty(x => x.CollectionRequestId, (long?)null));
            await _context.SaveChangesAsync();

            await _finance.WriteAuditAsync(actorUserId, "CollectionRequestRejected", request.DriverId, $"request={requestId} {note}");
            await SafeNotifyAsync(request.DriverId, "طلب التحويل اترفض",
                $"طلب تحويل {request.Amount:0.##} ج.م اترفض: {note}", "driver_collection_rejected");

            var result = await AdminRequestQuery(_context.CollectionRequests.AsNoTracking().Where(r => r.Id == requestId)).FirstAsync();
            return Response<AdminCollectionRequestDTO>.Success(result, "تم رفض الطلب", 200);
        }

        public async Task<Response<string>> UnlockDriverAsync(string driverId, ReviewNoteDTO dto, string actorUserId)
        {
            var note = (dto.Note ?? string.Empty).Trim();
            if (note.Length < 3) return Response<string>.Failure("اكتب سبب فك القفل", 400);
            var updated = await _context.Users.Where(u => u.Id == driverId && u.CollectionLockedAt != null)
                .ExecuteUpdateAsync(s => s.SetProperty(u => u.CollectionLockedAt, (DateTime?)null));
            if (updated == 0) return Response<string>.Failure("الكابتن مش مقفول عليه بسبب التحصيل", 400);

            _finance.InvalidateEligibility(driverId);
            await _finance.WriteAuditAsync(actorUserId, "CollectionLockReleased", driverId, note);
            await SafeNotifyAsync(driverId, "اتفتح استقبال الرحلات",
                "الإدارة فتحت حسابك. افتكر تحوّل المستحقات قبل ميعاد التحصيل الجاي.", "driver_collection_unlocked");
            return Response<string>.Success("ok", "تم فك القفل لحد ميعاد التحصيل الجاي", 200);
        }

        private async Task<List<AdminWalletDTO>> WalletDtosAsync(int? id = null)
        {
            var onlineSince = Now - DeviceOnlineWindow;
            var rows = await _context.CollectionWallets.AsNoTracking()
                .Where(w => id == null || w.Id == id)
                .OrderBy(w => w.SortOrder).ThenBy(w => w.Id)
                .Select(w => new AdminWalletDTO
                {
                    Id = w.Id,
                    Provider = w.Provider.ToString(),
                    PhoneNumber = w.PhoneNumber,
                    HolderName = w.HolderName,
                    BankName = w.BankName,
                    IsOnline = w.Device != null && w.Device.IsActive && w.Device.LastSeenAt >= onlineSince,
                    IsActive = w.IsActive,
                    SortOrder = w.SortOrder,
                    DeviceId = w.DeviceId,
                    DeviceName = w.Device != null ? w.Device.Name : null,
                    LastSmsAt = w.LastSmsAt,
                }).ToListAsync();
            foreach (var w in rows) w.ProviderLabel = ProviderLabel(Enum.Parse<WalletProvider>(w.Provider));
            return rows;
        }

        public async Task<Response<List<AdminWalletDTO>>> GetWalletsAsync() =>
            Response<List<AdminWalletDTO>>.Success(await WalletDtosAsync(), "", 200);

        public async Task<Response<AdminWalletDTO>> SaveWalletAsync(int? walletId, WalletUpsertDTO dto, string actorUserId)
        {
            if (!Enum.TryParse<WalletProvider>(dto.Provider, true, out var provider) || !Enum.IsDefined(provider))
                return Response<AdminWalletDTO>.Failure("اختار نوع المحفظة", 400);
            // InstaPay is received on an address (name@instapay) or a mobile number; the
            // wallets only on a mobile number.
            var phone = provider == WalletProvider.InstaPay
                ? WalletSmsParser.NormalizeInstaPayAddress(dto.PhoneNumber) ?? WalletSmsParser.NormalizePhone(dto.PhoneNumber)
                : WalletSmsParser.NormalizePhone(dto.PhoneNumber);
            if (phone == null)
                return Response<AdminWalletDTO>.Failure(provider == WalletProvider.InstaPay
                    ? "اكتب عنوان انستاباي (name@instapay) أو رقم الموبايل المربوط بيه"
                    : "رقم المحفظة لازم يكون رقم موبايل مصري 11 رقم", 400);
            var holder = (dto.HolderName ?? string.Empty).Trim();
            if (holder.Length < 2 || holder.Length > 100) return Response<AdminWalletDTO>.Failure("اكتب اسم صاحب الحساب", 400);
            var bank = Clip(dto.BankName, 100);
            if (dto.DeviceId != null && !await _context.CollectorDevices.AnyAsync(d => d.Id == dto.DeviceId))
                return Response<AdminWalletDTO>.Failure("موبايل التحصيل مش موجود", 400);
            if (await _context.CollectionWallets.AnyAsync(w => w.Provider == provider && w.PhoneNumber == phone && w.Id != walletId))
                return Response<AdminWalletDTO>.Failure("المحفظة دي متسجلة بالفعل", 400);

            CollectionWallet? wallet;
            if (walletId == null)
            {
                wallet = new CollectionWallet { CreatedAt = Now };
                _context.CollectionWallets.Add(wallet);
            }
            else
            {
                wallet = await _context.CollectionWallets.FirstOrDefaultAsync(w => w.Id == walletId);
                if (wallet == null) return Response<AdminWalletDTO>.Failure("المحفظة مش موجودة", 404);
            }
            wallet.Provider = provider;
            wallet.PhoneNumber = phone;
            wallet.HolderName = holder;
            wallet.BankName = provider == WalletProvider.InstaPay ? bank : null;
            wallet.IsActive = dto.IsActive;
            wallet.SortOrder = dto.SortOrder;
            wallet.DeviceId = dto.DeviceId;
            await _context.SaveChangesAsync();

            await _finance.WriteAuditAsync(actorUserId, walletId == null ? "CollectionWalletAdded" : "CollectionWalletUpdated", null,
                $"{provider} {phone} ({holder}) active={dto.IsActive}");
            return Response<AdminWalletDTO>.Success((await WalletDtosAsync(wallet.Id)).First(), "تم حفظ المحفظة", walletId == null ? 201 : 200);
        }

        private async Task<List<CollectorDeviceDTO>> DeviceDtosAsync(Guid? id = null)
        {
            var now = Now;
            var onlineSince = now - DeviceOnlineWindow;
            var devices = await _context.CollectorDevices.AsNoTracking()
                .Where(d => id == null || d.Id == id)
                .OrderBy(d => d.CreatedAt).ToListAsync();
            var wallets = await _context.CollectionWallets.AsNoTracking().Where(w => w.DeviceId != null).ToListAsync();
            return devices.Select(d => new CollectorDeviceDTO
            {
                Id = d.Id,
                Name = d.Name,
                IsActive = d.IsActive,
                Paired = d.KeyHash != null,
                PairingCode = d.PairingExpiresAt > now ? d.PairingCode : null,
                PairingExpiresAt = d.PairingExpiresAt > now ? d.PairingExpiresAt : null,
                PairedAt = d.PairedAt,
                LastSeenAt = d.LastSeenAt,
                Online = d.IsActive && d.KeyHash != null && d.LastSeenAt >= onlineSince,
                AppVersion = d.AppVersion,
                LastStatus = d.LastStatus,
                Wallets = wallets.Where(w => w.DeviceId == d.Id).Select(w => $"{ProviderLabel(w.Provider)} {w.PhoneNumber}").ToList(),
            }).ToList();
        }

        public async Task<Response<List<CollectorDeviceDTO>>> GetDevicesAsync() =>
            Response<List<CollectorDeviceDTO>>.Success(await DeviceDtosAsync(), "", 200);

        public async Task<Response<CollectorDeviceDTO>> CreateDeviceAsync(CreateDeviceDTO dto, string actorUserId)
        {
            var name = (dto.Name ?? string.Empty).Trim();
            if (name.Length < 2 || name.Length > 100) return Response<CollectorDeviceDTO>.Failure("اكتب اسم للموبايل", 400);
            var now = Now;
            var device = new CollectorDevice
            {
                Id = Guid.NewGuid(),
                Name = name,
                PairingCode = NewPairingCode(),
                PairingExpiresAt = now + PairingCodeLife,
                CreatedAt = now,
                CreatedByUserId = actorUserId,
            };
            _context.CollectorDevices.Add(device);
            await _context.SaveChangesAsync();
            await _finance.WriteAuditAsync(actorUserId, "CollectorDeviceAdded", null, name);
            return Response<CollectorDeviceDTO>.Success((await DeviceDtosAsync(device.Id)).First(), "اكتب الكود في تطبيق التحصيل خلال 30 دقيقة", 201);
        }

        public async Task<Response<CollectorDeviceDTO>> NewPairingCodeAsync(Guid deviceId, string actorUserId)
        {
            var device = await _context.CollectorDevices.FirstOrDefaultAsync(d => d.Id == deviceId);
            if (device == null) return Response<CollectorDeviceDTO>.Failure("الموبايل مش موجود", 404);
            device.PairingCode = NewPairingCode();
            device.PairingExpiresAt = Now + PairingCodeLife;
            await _context.SaveChangesAsync();
            await _finance.WriteAuditAsync(actorUserId, "CollectorPairingCode", null, device.Name);
            return Response<CollectorDeviceDTO>.Success((await DeviceDtosAsync(device.Id)).First(), "كود ربط جديد", 200);
        }

        public async Task<Response<CollectorDeviceDTO>> SetDeviceActiveAsync(Guid deviceId, bool active, string actorUserId)
        {
            var device = await _context.CollectorDevices.FirstOrDefaultAsync(d => d.Id == deviceId);
            if (device == null) return Response<CollectorDeviceDTO>.Failure("الموبايل مش موجود", 404);
            device.IsActive = active;
            if (!active) { device.PairingCode = null; device.PairingExpiresAt = null; }
            await _context.SaveChangesAsync();
            await _finance.WriteAuditAsync(actorUserId, active ? "CollectorDeviceEnabled" : "CollectorDeviceDisabled", null, device.Name);
            return Response<CollectorDeviceDTO>.Success((await DeviceDtosAsync(device.Id)).First(), active ? "تم التفعيل" : "تم الإيقاف", 200);
        }

        #endregion

        #region Daily cycle

        private async Task<CollectionCycle> GetOrCreateCycleAsync(DateTime date)
        {
            var cycle = await _context.CollectionCycles.AsNoTracking().FirstOrDefaultAsync(c => c.CycleDate == date);
            if (cycle != null) return cycle;
            try
            {
                cycle = new CollectionCycle { CycleDate = date };
                _context.CollectionCycles.Add(cycle);
                await _context.SaveChangesAsync();
                _context.Entry(cycle).State = EntityState.Detached;
                return cycle;
            }
            catch (DbUpdateException)
            {
                // Another instance created it first.
                _context.ChangeTracker.Clear();
                return await _context.CollectionCycles.AsNoTracking().FirstAsync(c => c.CycleDate == date);
            }
        }

        public async Task RunCycleAsync()
        {
            await ExpireStaleRequestsAsync();

            var rule = await GetRuleAsync();
            if (!rule.CollectionEnabled) return;

            var now = Now;
            await AlertIfCollectorOfflineAsync(now);
            var (date, notice, deadline) = CurrentCycle(now, rule.CollectionNoticeHour, rule.CollectionDeadlineHour);
            var cycle = await GetOrCreateCycleAsync(date);
            var id = cycle.Id;
            var tolerance = rule.CollectionTolerance;
            var deadlineLabel = DeadlineLabel(deadline);

            // Evening notice.
            if (cycle.NoticeSentAt == null && now >= notice && now < deadline
                && await _context.CollectionCycles.Where(c => c.Id == id && c.NoticeSentAt == null)
                       .ExecuteUpdateAsync(s => s.SetProperty(c => c.NoticeSentAt, now)) == 1)
            {
                var owing = await DriversOwingAsync(tolerance);
                foreach (var (driverId, owed) in owing)
                    await SafeNotifyAsync(driverId, "تحصيل اليوم 💰",
                        $"عليك {owed:0.##} ج.م للشركة. حوّلهم على محفظة الشركة من صفحة الحسابات قبل الساعة {deadlineLabel} علشان استقبال الرحلات ما يتوقفش.",
                        "driver_collection_notice");
                await _context.CollectionCycles.Where(c => c.Id == id)
                    .ExecuteUpdateAsync(s => s.SetProperty(c => c.NoticeCount, owing.Count));
                Log.Information("Collection notice for {Date:yyyy-MM-dd}: {Count} captains", date, owing.Count);
            }

            // Last-hour reminder, skipping captains who already filed a request.
            if (cycle.ReminderSentAt == null && now >= deadline.AddHours(-1) && now < deadline
                && await _context.CollectionCycles.Where(c => c.Id == id && c.ReminderSentAt == null)
                       .ExecuteUpdateAsync(s => s.SetProperty(c => c.ReminderSentAt, now)) == 1)
            {
                var owing = await DriversOwingAsync(tolerance);
                var filed = await _context.CollectionRequests
                    .Where(r => r.Status == CollectionRequestStatus.Pending && r.CreatedAt >= notice)
                    .Select(r => r.DriverId).Distinct().ToListAsync();
                var targets = owing.Where(o => !filed.Contains(o.Key)).ToList();
                foreach (var (driverId, owed) in targets)
                    await SafeNotifyAsync(driverId, "فاضل ساعة على التحصيل ⏰",
                        $"لسه عليك {owed:0.##} ج.م. حوّلهم قبل الساعة {deadlineLabel} وإلا استقبال الرحلات هيتوقف لحد التحويل.",
                        "driver_collection_reminder");
                await _context.CollectionCycles.Where(c => c.Id == id)
                    .ExecuteUpdateAsync(s => s.SetProperty(c => c.ReminderCount, targets.Count));
            }

            // Deadline: lock everyone still above the tolerance.
            if (cycle.LockAppliedAt == null && now >= deadline
                && await _context.CollectionCycles.Where(c => c.Id == id && c.LockAppliedAt == null)
                       .ExecuteUpdateAsync(s => s.SetProperty(c => c.LockAppliedAt, now)) == 1)
            {
                var collectorAlive = await _context.CollectorDevices
                    .AnyAsync(d => d.IsActive && d.KeyHash != null && d.LastSeenAt >= now - DeviceLockGuard);
                if (!collectorAlive)
                {
                    const string note = "القفل اتلغى: موبايل التحصيل مش متصل، ومش هنقدر نأكد مين حوّل";
                    await _context.CollectionCycles.Where(c => c.Id == id)
                        .ExecuteUpdateAsync(s => s.SetProperty(c => c.LockNote, note));
                    await NotifyAdminsAsync("تحصيل الكباتن: القفل اتلغى", note, "admin_collection_device_offline");
                    Log.Warning("Collection lock for {Date:yyyy-MM-dd} skipped: no collector device online", date);
                    return;
                }

                var owing = await DriversOwingAsync(tolerance);
                var ids = owing.Keys.ToList();
                var locked = 0;
                foreach (var chunk in ids.Chunk(500))
                    locked += await _context.Users
                        .Where(u => chunk.Contains(u.Id) && u.CollectionLockedAt == null)
                        .ExecuteUpdateAsync(s => s.SetProperty(u => u.CollectionLockedAt, now));

                foreach (var (driverId, owed) in owing)
                {
                    await _finance.EnforceEligibilityAsync(driverId);
                    await SafeNotifyAsync(driverId, "تم إيقاف استقبال الرحلات",
                        $"عدّى ميعاد التحصيل وعليك {owed:0.##} ج.م. حوّل المبلغ على محفظة الشركة من صفحة الحسابات، والحساب هيتفتح لوحده أول ما التحويل يتأكد.",
                        "driver_collection_locked");
                }
                await _context.CollectionCycles.Where(c => c.Id == id)
                    .ExecuteUpdateAsync(s => s.SetProperty(c => c.LockedCount, owing.Count));
                Log.Information("Collection deadline {Date:yyyy-MM-dd}: {Count} captains locked ({New} new)", date, owing.Count, locked);
            }
        }

        // Paired collector phones that stopped reporting: tell the admins (at most every
        // two hours while it lasts) — no phone means no confirmations and, at the
        // deadline, no lock.
        private static DateTime _lastOfflineAlert = DateTime.MinValue;
        private static readonly TimeSpan OfflineAlertAfter = TimeSpan.FromMinutes(15);

        private async Task AlertIfCollectorOfflineAsync(DateTime now)
        {
            if (now - _lastOfflineAlert < TimeSpan.FromHours(2)) return;
            var devices = await _context.CollectorDevices.AsNoTracking()
                .Where(d => d.IsActive && d.KeyHash != null)
                .Select(d => new { d.Name, d.LastSeenAt }).ToListAsync();
            if (devices.Count == 0 || devices.Any(d => d.LastSeenAt >= now - OfflineAlertAfter)) return;

            _lastOfflineAlert = now;
            var names = string.Join("، ", devices.Select(d => d.Name));
            await NotifyAdminsAsync("موبايل التحصيل مش متصل ⚠",
                $"{names} ما بعتش من أكتر من {OfflineAlertAfter.TotalMinutes:0} دقيقة. التحويلات مش هتتأكد لحد ما يرجع (اتأكد من النت والشحن والتطبيق).",
                "admin_collection_device_offline");
            Log.Warning("Collector devices offline: {Names}", names);
        }

        // Pending requests with no receipt SMS after the match window expire (a late SMS
        // can still confirm them) and the captain is told to check the number.
        private async Task ExpireStaleRequestsAsync()
        {
            var cutoff = Now - MatchWindow;
            var stale = await _context.CollectionRequests.AsNoTracking()
                .Where(r => r.Status == CollectionRequestStatus.Pending && r.CreatedAt < cutoff)
                .Select(r => new { r.Id, r.DriverId, r.Amount, Sender = r.SenderPhone ?? r.SenderAccount ?? r.SenderName })
                .Take(200).ToListAsync();
            foreach (var r in stale)
            {
                var updated = await _context.CollectionRequests
                    .Where(x => x.Id == r.Id && x.Status == CollectionRequestStatus.Pending)
                    .ExecuteUpdateAsync(s => s
                        .SetProperty(x => x.Status, CollectionRequestStatus.Expired)
                        .SetProperty(x => x.Note, "ما وصلتش رسالة استلام بالرقم والمبلغ دول — الإدارة هتراجع"));
                if (updated == 1)
                    await SafeNotifyAsync(r.DriverId, "مالقيناش التحويل",
                        $"ما وصلناش تحويل {r.Amount:0.##} ج.م من {r.Sender}. اتأكد من البيانات والمبلغ أو كلّم الدعم.",
                        "driver_collection_expired");
            }
        }

        #endregion
    }
}
