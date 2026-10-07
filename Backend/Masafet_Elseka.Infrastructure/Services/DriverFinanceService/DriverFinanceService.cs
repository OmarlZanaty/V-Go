using Masafet_Elseka.Application.Common.Pagination;
using Masafet_Elseka.Application.DTOs.DriverFinance;
using Masafet_Elseka.Application.Interfaces.IDriverFinanceService;
using Masafet_Elseka.Application.Interfaces.INotificationService;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Const;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Data;
using Masafet_Elseka.Infrastructure.Hubs;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Serilog;
using System.Collections.Concurrent;
using System.Text.RegularExpressions;

namespace Masafet_Elseka.Infrastructure.Services.DriverFinanceService
{
    // The captain's account with the company. Every money movement is an immutable
    // DriverLedgerEntry; the balance is their sum (+ company owes the captain,
    // - the captain owes the company). All posting goes through a per-captain SQL
    // app lock so concurrent webhooks / trip ends can't double-post.
    public class DriverFinanceService : IDriverFinanceService
    {
        private readonly Context _context;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly IHubContext<TripHub> _tripHub;
        private readonly INotificationService _notificationService;

        // Eligibility is checked on every idle location tick, so cache it briefly.
        // Anything that changes it (posting, settlement, approval) invalidates it.
        private static readonly ConcurrentDictionary<string, (OnlineEligibilityDTO Result, DateTime At)> _eligibilityCache = new();
        private static readonly TimeSpan EligibilityTtl = TimeSpan.FromSeconds(20);

        public static readonly DriverDocumentType[] RequiredDocuments =
        {
            DriverDocumentType.Selfie,
            DriverDocumentType.NationalIdFront,
            DriverDocumentType.NationalIdBack,
            DriverDocumentType.DriverLicense,
            DriverDocumentType.VehicleLicense,
        };

        public DriverFinanceService(Context context, UserManager<ApplicationUser> userManager,
            IHubContext<TripHub> tripHub, INotificationService notificationService)
        {
            _context = context;
            _userManager = userManager;
            _tripHub = tripHub;
            _notificationService = notificationService;
        }

        private static decimal Money(decimal value) => Math.Round(value, 2, MidpointRounding.AwayFromZero);
        private static DateTime Now => DateTime.Now.ToEgyptTime();

        #region Settings

        private async Task<PricingRule> GetRuleAsync()
        {
            // Defaults only matter on an empty database; production always has the row.
            return await _context.PricingRules.AsNoTracking().OrderBy(r => r.Id).FirstOrDefaultAsync()
                ?? new PricingRule { DriverCommissionPercentage = 100, CashLimit = 1000, WarningPercent = 80 };
        }

        private static decimal CompanyPercent(PricingRule rule) => Money(100 - rule.DriverCommissionPercentage);

        public async Task<DriverFinanceSettingsDTO> GetSettingsAsync()
        {
            var rule = await GetRuleAsync();
            return new DriverFinanceSettingsDTO
            {
                CompanyCommissionPercent = CompanyPercent(rule),
                CashLimit = rule.CashLimit,
                WarningPercent = rule.WarningPercent,
                LedgerStartAt = rule.LedgerStartAt,
                CollectionEnabled = rule.CollectionEnabled,
                CollectionNoticeHour = rule.CollectionNoticeHour,
                CollectionDeadlineHour = rule.CollectionDeadlineHour,
                CollectionTolerance = rule.CollectionTolerance,
            };
        }

        public async Task<Response<DriverFinanceSettingsDTO>> UpdateSettingsAsync(DriverFinanceSettingsDTO dto, string actorUserId)
        {
            if (dto.CompanyCommissionPercent < 0 || dto.CompanyCommissionPercent > 100)
                return Response<DriverFinanceSettingsDTO>.Failure("نسبة عمولة الشركة لازم تكون بين 0 و 100", 400);
            if (dto.CashLimit < 0 || dto.CashLimit > 1_000_000)
                return Response<DriverFinanceSettingsDTO>.Failure("حد المديونية غير صالح", 400);
            if (dto.WarningPercent < 1 || dto.WarningPercent > 100)
                return Response<DriverFinanceSettingsDTO>.Failure("نسبة التنبيه لازم تكون بين 1 و 100", 400);
            if (dto.CollectionNoticeHour is < 0 or > 23 || dto.CollectionDeadlineHour is < 0 or > 23)
                return Response<DriverFinanceSettingsDTO>.Failure("مواعيد التحصيل لازم تكون ساعة من 0 لـ 23", 400);
            if (dto.CollectionTolerance is < 0 or > 100_000)
                return Response<DriverFinanceSettingsDTO>.Failure("الحد المسموح بعد التحصيل غير صالح", 400);

            var rule = await _context.PricingRules.OrderBy(r => r.Id).FirstOrDefaultAsync();
            if (rule == null)
            {
                rule = new PricingRule { LedgerStartAt = Now };
                _context.PricingRules.Add(rule);
            }
            static string Describe(PricingRule r) =>
                $"commission={CompanyPercent(r)}%, limit={r.CashLimit}, warning={r.WarningPercent}%, " +
                $"collection={(r.CollectionEnabled ? "on" : "off")} {r.CollectionNoticeHour}:00->{r.CollectionDeadlineHour}:00 tolerance={r.CollectionTolerance}";
            var before = Describe(rule);
            var wasEnabled = rule.CollectionEnabled;

            var noticeHour = dto.CollectionNoticeHour ?? rule.CollectionNoticeHour;
            var deadlineHour = dto.CollectionDeadlineHour ?? rule.CollectionDeadlineHour;
            if (noticeHour == deadlineHour)
                return Response<DriverFinanceSettingsDTO>.Failure("ميعاد آخر مهلة لازم يختلف عن ميعاد إشعار التحصيل", 400);

            rule.DriverCommissionPercentage = Money(100 - dto.CompanyCommissionPercent);
            rule.CashLimit = Money(dto.CashLimit);
            rule.WarningPercent = dto.WarningPercent;
            if (dto.CollectionEnabled != null) rule.CollectionEnabled = dto.CollectionEnabled.Value;
            rule.CollectionNoticeHour = noticeHour;
            rule.CollectionDeadlineHour = deadlineHour;
            if (dto.CollectionTolerance != null) rule.CollectionTolerance = Money(dto.CollectionTolerance.Value);
            rule.LastUpdated = Now;
            await _context.SaveChangesAsync();

            // Turning collection off releases everyone it was holding.
            if (wasEnabled && !rule.CollectionEnabled)
                await _context.Users.Where(u => u.CollectionLockedAt != null)
                    .ExecuteUpdateAsync(x => x.SetProperty(u => u.CollectionLockedAt, (DateTime?)null));

            _eligibilityCache.Clear();
            await WriteAuditAsync(actorUserId, "FinanceSettingsUpdated", null, $"{before} -> {Describe(rule)}");

            return Response<DriverFinanceSettingsDTO>.Success(await GetSettingsAsync(), "تم حفظ إعدادات الماليات", 200);
        }

        #endregion

        #region Ledger posting

        // Serialises every write to one captain's ledger across requests and instances.
        private async Task AcquireDriverLockAsync(string driverId)
        {
            await _context.Database.ExecuteSqlRawAsync(
                "DECLARE @r int; EXEC @r = sp_getapplock @Resource = {0}, @LockMode = 'Exclusive', " +
                "@LockOwner = 'Transaction', @LockTimeout = 15000; " +
                "IF @r < 0 THROW 51000, 'driver ledger lock timeout', 1;",
                "driver-ledger:" + driverId);
        }

        private async Task<T> InDriverLockAsync<T>(string driverId, Func<Task<T>> work)
        {
            if (_context.Database.CurrentTransaction != null)
            {
                await AcquireDriverLockAsync(driverId);
                return await work();
            }

            await using var tx = await _context.Database.BeginTransactionAsync();
            await AcquireDriverLockAsync(driverId);
            var result = await work();
            await tx.CommitAsync();
            return result;
        }

        private async Task<decimal> SumBalanceAsync(string driverId) =>
            await _context.DriverLedgerEntries.IgnoreQueryFilters()
                .Where(e => e.DriverId == driverId)
                .SumAsync(e => (decimal?)e.Amount) ?? 0m;

        public async Task SyncTripLedgerAsync(string tripId)
        {
            if (string.IsNullOrEmpty(tripId)) return;
            try
            {
                var trip = await _context.Trips.AsNoTracking()
                    .Include(t => t.Payment)
                    .Include(t => t.UserTrips)
                    .FirstOrDefaultAsync(t => t.Id == tripId);
                if (trip == null || trip.Status != TripStatus.Completed) return;

                var driverId = trip.UserTrips.FirstOrDefault(ut => ut.Role == UserTripRole.Driver)?.UserId;
                if (string.IsNullOrEmpty(driverId)) return;

                var rule = await GetRuleAsync();
                var endedAt = trip.EndTime ?? trip.CreatedAt;
                if (rule.LedgerStartAt.HasValue && endedAt < rule.LedgerStartAt.Value) return;

                // How the fare was actually settled decides who holds the money:
                // paid online -> the company has it; cash -> the captain has it.
                static bool Settled(Payment p) => p.Status is PaymentStatus.Paid or PaymentStatus.Captured;
                static bool IsCash(Payment p) => string.Equals(p.Method, "Cash", StringComparison.OrdinalIgnoreCase);
                var payments = trip.Payment.Where(p => p.Purpose == PaymentPurpose.Trip).ToList();
                var paidOnline = payments.Any(p => Settled(p) && !IsCash(p));
                var paidCash = payments.Any(p => Settled(p) && IsCash(p));
                var refused = payments.Any(p => p.FailureReason == Payment.ClientRefusedReason);
                var cashTrip = string.Equals(trip.PaymentMethod, "Cash", StringComparison.OrdinalIgnoreCase);

                LedgerEntryType? desiredType =
                    paidOnline ? LedgerEntryType.TripCardEarning
                    : (paidCash || (cashTrip && !refused)) ? LedgerEntryType.TripCashCommission
                    : null;

                var (before, after) = await InDriverLockAsync(driverId, async () =>
                {
                    var existing = await _context.DriverLedgerEntries.IgnoreQueryFilters()
                        .Where(e => e.TripId == tripId)
                        .OrderBy(e => e.Id)
                        .ToListAsync();

                    // The commission is frozen by the trip's first entry, so a later change
                    // to the rate never rewrites a past trip.
                    var percent = existing.FirstOrDefault(e => e.CommissionPercent != null)?.CommissionPercent
                        ?? CompanyPercent(rule);
                    var fare = Money(trip.Price);
                    var commission = Money(fare * percent / 100);
                    var share = fare - commission;
                    var desiredAmount = desiredType switch
                    {
                        LedgerEntryType.TripCashCommission => -commission,
                        LedgerEntryType.TripCardEarning => share,
                        _ => 0m
                    };

                    var existingNet = existing.Sum(e => e.Amount);
                    var last = existing.LastOrDefault();
                    LedgerEntryType? currentType = last == null || last.Type == LedgerEntryType.TripCorrection ? null : last.Type;

                    var balanceBefore = await SumBalanceAsync(driverId);
                    if (currentType == desiredType && existingNet == desiredAmount)
                        return (balanceBefore, balanceBefore);

                    var now = Now;
                    if (existingNet != 0)
                    {
                        _context.DriverLedgerEntries.Add(new DriverLedgerEntry
                        {
                            DriverId = driverId,
                            Type = LedgerEntryType.TripCorrection,
                            Amount = -existingNet,
                            TripId = tripId,
                            TripFare = fare,
                            Description = "تصحيح قيد الرحلة بعد تغيّر طريقة تحصيلها",
                            CreatedAt = now,
                        });
                    }
                    if (desiredType != null)
                    {
                        _context.DriverLedgerEntries.Add(new DriverLedgerEntry
                        {
                            DriverId = driverId,
                            Type = desiredType.Value,
                            Amount = desiredAmount,
                            TripId = tripId,
                            TripFare = fare,
                            CommissionPercent = percent,
                            CommissionAmount = commission,
                            Description = desiredType == LedgerEntryType.TripCashCommission
                                ? $"عمولة الشركة على رحلة كاش: {fare:0.##} ج.م × {percent:0.##}%"
                                : $"نصيبك من رحلة مدفوعة إلكترونياً: {fare:0.##} ج.م − عمولة {commission:0.##} ج.م",
                            CreatedAt = now,
                        });
                    }
                    await _context.SaveChangesAsync();
                    return (balanceBefore, balanceBefore - existingNet + desiredAmount);
                });

                if (before != after)
                    await AfterBalanceChangedAsync(driverId, before, after);
            }
            catch (Exception ex)
            {
                // Never break the trip / payment flow because of bookkeeping; the next
                // sync (any later payment event, or the admin) will repair it.
                Log.Error(ex, "SyncTripLedger failed for trip {TripId}", tripId);
            }
        }

        public async Task OnPaymentUpdatedAsync(string paymentId)
        {
            if (string.IsNullOrEmpty(paymentId)) return;
            try
            {
                var payment = await _context.Payments.AsNoTracking().FirstOrDefaultAsync(p => p.Id == paymentId);
                if (payment == null) return;

                if (payment.Purpose == PaymentPurpose.DriverSettlement)
                {
                    if (payment.Status is PaymentStatus.Paid or PaymentStatus.Captured)
                        await CreditSettlementAsync(payment);
                    return;
                }
                if (!string.IsNullOrEmpty(payment.TripId))
                    await SyncTripLedgerAsync(payment.TripId);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "OnPaymentUpdated failed for payment {PaymentId}", paymentId);
            }
        }

        private async Task CreditSettlementAsync(Payment payment)
        {
            var driverId = payment.UserId;
            (decimal Before, decimal After) result;
            try
            {
                result = await InDriverLockAsync(driverId, async () =>
                {
                    var balance = await SumBalanceAsync(driverId);
                    if (await _context.DriverLedgerEntries.IgnoreQueryFilters().AnyAsync(e => e.PaymentId == payment.Id))
                        return (balance, balance);

                    _context.DriverLedgerEntries.Add(new DriverLedgerEntry
                    {
                        DriverId = driverId,
                        Type = LedgerEntryType.Settlement,
                        Amount = Money(payment.Amount),
                        PaymentId = payment.Id,
                        Reference = payment.TransactionId,
                        Description = "سداد مستحقات الشركة عبر Paymob",
                        CreatedAt = Now,
                    });
                    await _context.SaveChangesAsync();
                    return (balance, balance + Money(payment.Amount));
                });
            }
            catch (DbUpdateException)
            {
                // Unique PaymentId index: another path credited it first.
                return;
            }

            if (result.Before == result.After) return;
            await AfterBalanceChangedAsync(driverId, result.Before, result.After, warn: false);
            await SafeNotifyAsync(driverId, "تم استلام السداد ✅",
                $"وصلنا {Money(payment.Amount):0.##} ج.م. رصيدك الحالي {result.After:0.##} ج.م.",
                "driver_settlement_credited");
        }

        // Credits a confirmed wallet transfer. Runs inside the caller's transaction (the
        // matcher marks the SMS and the request in the same one); the unique WalletSmsId
        // index guarantees one SMS is never credited twice.
        public async Task<(decimal Before, decimal After, bool Posted)> PostWalletCollectionAsync(
            string driverId, long walletSmsId, decimal amount, string description, string? reference, string? actorUserId)
        {
            return await InDriverLockAsync(driverId, async () =>
            {
                var balance = await SumBalanceAsync(driverId);
                if (await _context.DriverLedgerEntries.IgnoreQueryFilters().AnyAsync(e => e.WalletSmsId == walletSmsId))
                    return (balance, balance, false);

                var credit = Money(amount);
                _context.DriverLedgerEntries.Add(new DriverLedgerEntry
                {
                    DriverId = driverId,
                    Type = LedgerEntryType.WalletCollection,
                    Amount = credit,
                    WalletSmsId = walletSmsId,
                    Reference = reference,
                    Description = description,
                    CreatedByUserId = actorUserId,
                    CreatedAt = Now,
                });
                await _context.SaveChangesAsync();
                return (balance, balance + credit, true);
            });
        }

        // After the collection transaction committed: refresh the app, lift the daily
        // collection lock if the debt is back within the tolerance, and tell the captain.
        public async Task AfterWalletCollectionAsync(string driverId, decimal before, decimal after, decimal amount)
        {
            await AfterBalanceChangedAsync(driverId, before, after, warn: false);

            var rule = await GetRuleAsync();
            var owed = after < 0 ? -after : 0;
            var unlocked = false;
            if (owed <= rule.CollectionTolerance)
            {
                unlocked = await _context.Users.Where(u => u.Id == driverId && u.CollectionLockedAt != null)
                    .ExecuteUpdateAsync(x => x.SetProperty(u => u.CollectionLockedAt, (DateTime?)null)) > 0;
                InvalidateEligibility(driverId);
            }

            var body = owed > 0
                ? $"وصلنا {Money(amount):0.##} ج.م. المتبقي عليك {owed:0.##} ج.م."
                : $"وصلنا {Money(amount):0.##} ج.م وحسابك متسوّي.";
            if (unlocked) body += " اتفتح استقبال الرحلات، تقدر تشتغل دلوقتي.";
            await SafeNotifyAsync(driverId, "تم تأكيد التحويل ✅", body, "driver_collection_confirmed", save: true);
        }

        // Pushes the new balance to the captain's app and, when his debt grew, warns him
        // as it crosses the warning line or the limit.
        private async Task AfterBalanceChangedAsync(string driverId, decimal before, decimal after, bool warn = true)
        {
            InvalidateEligibility(driverId);
            try
            {
                await _tripHub.Clients.Group(HubGroups.User(driverId))
                    .SendAsync(HubEvents.DriverFinanceUpdated, new { Balance = after });
            }
            catch (Exception ex)
            {
                Log.Warning(ex, "DriverFinanceUpdated push failed for {DriverId}", driverId);
            }

            if (!warn || after >= before) return;

            // Debt grew: warn when it first crosses the warning line or the limit.
            var rule = await GetRuleAsync();
            if (rule.CashLimit <= 0) return;
            var limit = rule.CashLimit;
            var warnAt = Money(limit * rule.WarningPercent / 100m);
            var debtBefore = -before;
            var debtAfter = -after;
            if (debtBefore < limit && debtAfter >= limit)
            {
                await SafeNotifyAsync(driverId, "تم إيقاف استقبال الرحلات",
                    $"مستحقات الشركة عليك وصلت {debtAfter:0.##} ج.م (الحد {limit:0.##} ج.م). سدّد من صفحة الماليات علشان تكمل شغل.",
                    "driver_cash_limit_reached");
                await EnforceEligibilityAsync(driverId);
            }
            else if (debtBefore < warnAt && debtAfter >= warnAt)
            {
                await SafeNotifyAsync(driverId, "اقتربت من حد المديونية",
                    $"عليك {debtAfter:0.##} ج.م للشركة من أصل حد {limit:0.##} ج.م. سدّد قريباً علشان ما يتوقفش استقبال الرحلات.",
                    "driver_cash_limit_warning");
            }
        }

        private async Task SafeNotifyAsync(string userId, string title, string body, string type, bool save = false)
        {
            try
            {
                var data = new Dictionary<string, string> { { "type", type } };
                if (save)
                    await _notificationService.SendNotificationToUserWithSavingAsync(userId, title, body, data);
                else
                    await _notificationService.SendNotificationToUserAsync(userId, title, body, data);
            }
            catch (Exception ex)
            {
                Log.Warning(ex, "Finance notification {Type} failed for {UserId}", type, userId);
            }
        }

        #endregion

        #region Eligibility

        public void InvalidateEligibility(string driverId) => _eligibilityCache.TryRemove(driverId, out _);

        public async Task<OnlineEligibilityDTO> CheckOnlineEligibilityAsync(string driverId, bool useCache = false)
        {
            if (useCache && _eligibilityCache.TryGetValue(driverId, out var cached)
                && DateTime.UtcNow - cached.At < EligibilityTtl)
                return cached.Result;

            var result = await ComputeEligibilityAsync(driverId);
            _eligibilityCache[driverId] = (result, DateTime.UtcNow);
            return result;
        }

        private static OnlineEligibilityDTO Blocked(string code, string message) =>
            new() { CanGoOnline = false, Code = code, Message = message };

        private async Task<OnlineEligibilityDTO> ComputeEligibilityAsync(string driverId)
        {
            var user = await _context.Users.AsNoTracking()
                .Where(u => u.Id == driverId)
                .Select(u => new { u.IsBlocked, u.VerificationStatus, u.VerificationNote, u.DocumentsDeadline, u.CollectionLockedAt })
                .FirstOrDefaultAsync();
            if (user == null) return Blocked("NOT_DRIVER", "الحساب غير موجود");
            if (user.IsBlocked) return Blocked("BLOCKED", "حسابك موقوف، تواصل مع الدعم");

            switch (user.VerificationStatus)
            {
                case DriverVerificationStatus.Suspended:
                    return Blocked("SUSPENDED", string.IsNullOrWhiteSpace(user.VerificationNote)
                        ? "تم إيقاف حسابك من الإدارة، تواصل مع الدعم"
                        : $"تم إيقاف حسابك من الإدارة: {user.VerificationNote}");
                case DriverVerificationStatus.PendingDocuments:
                    return Blocked("KYC_PENDING", "ارفع صورتك ومستنداتك علشان تقدر تبدأ تشتغل");
                case DriverVerificationStatus.UnderReview:
                    return Blocked("KYC_UNDER_REVIEW", "مستنداتك قيد المراجعة، هنبلغك أول ما تتم الموافقة");
                case DriverVerificationStatus.Rejected:
                    return Blocked("KYC_REJECTED", string.IsNullOrWhiteSpace(user.VerificationNote)
                        ? "تم رفض بعض المستندات، أعد رفعها من صفحة التوثيق"
                        : $"تم رفض بعض المستندات: {user.VerificationNote}");
            }

            // Approved before documents were required: fine until the grace period ends.
            if (user.DocumentsDeadline.HasValue && Now > user.DocumentsDeadline.Value)
            {
                var uploaded = await _context.DriverDocuments
                    .Where(d => d.DriverId == driverId && d.Status != DriverDocumentStatus.Rejected)
                    .Select(d => d.Type).Distinct().CountAsync();
                if (uploaded < RequiredDocuments.Length)
                    return Blocked("DOCS_OVERDUE", "انتهت مهلة رفع المستندات. ارفع صورتك ومستنداتك علشان تقدر تشتغل تاني");
            }

            var rule = await GetRuleAsync();

            // Missed the daily collection deadline: offline until the transfer is confirmed.
            if (user.CollectionLockedAt != null)
            {
                var owed = -await GetBalanceAsync(driverId);
                if (rule.CollectionEnabled && owed > rule.CollectionTolerance)
                    return Blocked("COLLECTION_OVERDUE",
                        $"عليك {owed:0.##} ج.م للشركة وعدّى ميعاد التحصيل. حوّل المبلغ على محفظة الشركة من صفحة الحسابات، " +
                        "وأول ما رسالة الاستلام توصل الحساب هيتفتح لوحده.");
                // Paid (or collection turned off) since: release the lock.
                await _context.Users.Where(u => u.Id == driverId)
                    .ExecuteUpdateAsync(x => x.SetProperty(u => u.CollectionLockedAt, (DateTime?)null));
            }

            if (rule.CashLimit > 0)
            {
                var balance = await GetBalanceAsync(driverId);
                if (-balance >= rule.CashLimit)
                    return Blocked("CASH_LIMIT",
                        $"عليك {-balance:0.##} ج.م للشركة ودي وصلت للحد المسموح ({rule.CashLimit:0.##} ج.م). سدّد المستحقات علشان تقدر تكمل شغل.");
            }

            return new OnlineEligibilityDTO { CanGoOnline = true };
        }

        public async Task EnforceEligibilityAsync(string driverId)
        {
            try
            {
                InvalidateEligibility(driverId);
                var eligibility = await CheckOnlineEligibilityAsync(driverId);
                if (eligibility.CanGoOnline) return;

                await _context.Users.Where(u => u.Id == driverId && u.IsAvailable == true)
                    .ExecuteUpdateAsync(s => s.SetProperty(u => u.IsAvailable, false));
                await _tripHub.Clients.Group(HubGroups.User(driverId))
                    .SendAsync(HubEvents.DriverOnlineBlocked, eligibility);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "EnforceEligibility failed for {DriverId}", driverId);
            }
        }

        #endregion

        #region Captain

        public async Task<decimal> GetBalanceAsync(string driverId) => await SumBalanceAsync(driverId);

        private record TripEntryRow(long Id, string TripId, LedgerEntryType Type, decimal Amount,
            decimal? Fare, decimal? Commission, DateTime CreatedAt, DateTime? TripEndTime);

        // Each trip's current state is its last entry, unless a correction voided it.
        private static List<TripEntryRow> FinalTripEntries(IEnumerable<TripEntryRow> rows) =>
            rows.GroupBy(r => r.TripId)
                .Select(g => g.OrderBy(r => r.Id).Last())
                .Where(r => r.Type != LedgerEntryType.TripCorrection)
                .ToList();

        private static PeriodTotalsDTO Totals(IEnumerable<TripEntryRow> rows)
        {
            var list = rows.ToList();
            return new PeriodTotalsDTO
            {
                Trips = list.Count,
                GrossFare = list.Sum(r => r.Fare ?? 0),
                CompanyCommission = list.Sum(r => r.Commission ?? 0),
                DriverNet = list.Sum(r => (r.Fare ?? 0) - (r.Commission ?? 0)),
                CashCollected = list.Where(r => r.Type == LedgerEntryType.TripCashCommission).Sum(r => r.Fare ?? 0),
                OnlineCollected = list.Where(r => r.Type == LedgerEntryType.TripCardEarning).Sum(r => r.Fare ?? 0),
            };
        }

        public async Task<Response<DriverFinanceSummaryDTO>> GetSummaryAsync(string driverId)
        {
            var user = await _context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == driverId);
            if (user == null) return Response<DriverFinanceSummaryDTO>.Failure("الكابتن غير موجود", 404);

            var rule = await GetRuleAsync();
            var balance = await GetBalanceAsync(driverId);

            var rows = await _context.DriverLedgerEntries.IgnoreQueryFilters()
                .Where(e => e.DriverId == driverId && e.TripId != null)
                .Select(e => new TripEntryRow(e.Id, e.TripId!, e.Type, e.Amount, e.TripFare,
                    e.CommissionAmount, e.CreatedAt, e.Trip!.EndTime))
                .ToListAsync();
            var final = FinalTripEntries(rows);

            var now = Now;
            var today = now.Date;
            DateTime When(TripEntryRow r) => r.TripEndTime ?? r.CreatedAt;

            var debt = balance < 0 ? -balance : 0;
            var limitUsed = rule.CashLimit > 0 ? Math.Min(100, Money(debt / rule.CashLimit * 100)) : 0;
            var eligibility = await CheckOnlineEligibilityAsync(driverId);

            return Response<DriverFinanceSummaryDTO>.Success(new DriverFinanceSummaryDTO
            {
                DriverId = driverId,
                DriverName = user.FullName,
                Balance = balance,
                OwedToCompany = debt,
                OwedToDriver = balance > 0 ? balance : 0,
                CompanyCommissionPercent = CompanyPercent(rule),
                CashLimit = rule.CashLimit,
                WarningPercent = rule.WarningPercent,
                LimitUsedPercent = limitUsed,
                IsNearLimit = rule.CashLimit > 0 && limitUsed >= rule.WarningPercent,
                IsLocked = rule.CashLimit > 0 && debt >= rule.CashLimit,
                CollectionEnabled = rule.CollectionEnabled,
                CollectionLocked = eligibility.Code == "COLLECTION_OVERDUE",
                CollectionTolerance = rule.CollectionTolerance,
                Today = Totals(final.Where(r => When(r) >= today)),
                Week = Totals(final.Where(r => When(r) >= today.AddDays(-6))),
                Month = Totals(final.Where(r => When(r) >= new DateTime(today.Year, today.Month, 1))),
                AllTime = Totals(final),
                PayoutMethod = user.PayoutMethod?.ToString(),
                PayoutAccount = user.PayoutAccount,
                PayoutAccountName = user.PayoutAccountName,
                PayoutUpdatedAt = user.PayoutUpdatedAt,
                VerificationStatus = user.VerificationStatus.ToString(),
                Eligibility = eligibility,
            }, "", 200);
        }

        public async Task<Response<PaginationPagedResponse<LedgerEntryDTO>>> GetLedgerAsync(string driverId, PaginationRequest pagination, string? type = null)
        {
            var page = Math.Max(1, pagination.PageNumber);
            var size = Math.Clamp(pagination.PageSize, 1, 100);

            var query = _context.DriverLedgerEntries.IgnoreQueryFilters().Where(e => e.DriverId == driverId);
            if (!string.IsNullOrWhiteSpace(type) && Enum.TryParse<LedgerEntryType>(type, true, out var t))
                query = query.Where(e => e.Type == t);

            var total = await query.CountAsync();
            var items = await query
                .OrderByDescending(e => e.Id)
                .Skip((page - 1) * size).Take(size)
                .Select(e => new LedgerEntryDTO
                {
                    Id = e.Id,
                    Type = e.Type.ToString(),
                    Amount = e.Amount,
                    TripId = e.TripId,
                    TripFare = e.TripFare,
                    CommissionPercent = e.CommissionPercent,
                    CommissionAmount = e.CommissionAmount,
                    DriverNet = e.TripFare != null && e.CommissionAmount != null ? e.TripFare - e.CommissionAmount : null,
                    TripPaymentMethod = e.Trip != null ? e.Trip.PaymentMethod : null,
                    PaymentId = e.PaymentId,
                    Description = e.Description,
                    Reference = e.Reference,
                    AttachmentUrl = e.AttachmentUrl != null ? "DriverFinance/ledger/" + e.Id + "/attachment" : null,
                    CreatedByName = e.CreatedByUserId == null ? null
                        : _context.Users.IgnoreQueryFilters().Where(u => u.Id == e.CreatedByUserId).Select(u => u.FullName).FirstOrDefault(),
                    CreatedAt = e.CreatedAt,
                })
                .ToListAsync();

            return Response<PaginationPagedResponse<LedgerEntryDTO>>.Success(
                new PaginationPagedResponse<LedgerEntryDTO>(items, total, page, size), "", 200);
        }

        private static readonly Regex EgyptMobile = new(@"^01[0125]\d{8}$", RegexOptions.Compiled);
        private static readonly Regex InstaPayAddress = new(@"^[A-Za-z0-9._-]{3,50}@instapay$", RegexOptions.Compiled | RegexOptions.IgnoreCase);

        public async Task<Response<string>> SetPayoutAccountAsync(string driverId, SetPayoutAccountDTO dto)
        {
            if (!Enum.TryParse<PayoutMethod>(dto.Method, true, out var method) || !Enum.IsDefined(method))
                return Response<string>.Failure("اختار طريقة الاستلام: انستاباي أو محفظة", 400);

            var account = (dto.Account ?? string.Empty).Trim().Replace(" ", "");
            if (account.StartsWith("+20")) account = "0" + account[3..];
            var validAccount = method == PayoutMethod.MobileWallet
                ? EgyptMobile.IsMatch(account)
                : EgyptMobile.IsMatch(account) || InstaPayAddress.IsMatch(account);
            if (!validAccount)
                return Response<string>.Failure(method == PayoutMethod.MobileWallet
                    ? "رقم المحفظة لازم يكون رقم موبايل مصري صحيح (11 رقم)"
                    : "اكتب رقم موبايل مصري أو عنوان انستاباي (مثال name@instapay)", 400);

            var name = (dto.AccountName ?? string.Empty).Trim();
            if (name.Length < 3 || name.Length > 100)
                return Response<string>.Failure("اكتب اسم صاحب الحساب كما هو مسجل", 400);

            var user = await _userManager.FindByIdAsync(driverId);
            if (user == null) return Response<string>.Failure("الكابتن غير موجود", 404);
            if (string.IsNullOrEmpty(dto.Password) || !await _userManager.CheckPasswordAsync(user, dto.Password))
                return Response<string>.Failure("كلمة المرور غير صحيحة", 400);

            var previous = user.PayoutAccount == null ? "لا يوجد" : $"{user.PayoutMethod} {user.PayoutAccount}";
            user.PayoutMethod = method;
            user.PayoutAccount = account;
            user.PayoutAccountName = name;
            user.PayoutUpdatedAt = Now;
            await _userManager.UpdateAsync(user);

            await WriteAuditAsync(driverId, "PayoutAccountChanged", driverId, $"{previous} -> {method} {account} ({name})");

            // Tell the admins: a changed payout destination is the first thing to check
            // if a captain's account is ever taken over.
            try
            {
                var adminIds = await (from u in _context.Users
                                      join ur in _context.UserRoles on u.Id equals ur.UserId
                                      join r in _context.Roles on ur.RoleId equals r.Id
                                      where r.Name == "Admin" || r.Name == "Accountant"
                                      select u.Id).Distinct().ToListAsync();
                foreach (var adminId in adminIds)
                    await SafeNotifyAsync(adminId, "تغيير حساب استلام أرباح",
                        $"الكابتن {user.FullName} غيّر حساب الاستلام إلى {method} {account}", "driver_payout_account_changed");
            }
            catch (Exception ex)
            {
                Log.Warning(ex, "Admin notify for payout change failed");
            }

            return Response<string>.Success("ok", "تم حفظ حساب استلام الأرباح", 200);
        }

        public async Task<Response<SettlementStatusDTO>> GetSettlementStatusAsync(string driverId, string paymentId)
        {
            var payment = await _context.Payments.AsNoTracking()
                .FirstOrDefaultAsync(p => p.Id == paymentId && p.UserId == driverId && p.Purpose == PaymentPurpose.DriverSettlement);
            if (payment == null) return Response<SettlementStatusDTO>.Failure("عملية السداد غير موجودة", 404);

            // Paid but not credited yet (e.g. the credit failed mid-way): credit now.
            var credited = await _context.DriverLedgerEntries.IgnoreQueryFilters().AnyAsync(e => e.PaymentId == paymentId);
            if (!credited && payment.Status is PaymentStatus.Paid or PaymentStatus.Captured)
            {
                await CreditSettlementAsync(payment);
                credited = await _context.DriverLedgerEntries.IgnoreQueryFilters().AnyAsync(e => e.PaymentId == paymentId);
            }

            var eligibility = await CheckOnlineEligibilityAsync(driverId);
            return Response<SettlementStatusDTO>.Success(new SettlementStatusDTO
            {
                PaymentId = payment.Id,
                Amount = payment.Amount,
                Status = payment.Status.ToString(),
                Credited = credited,
                Balance = await GetBalanceAsync(driverId),
                CanGoOnline = eligibility.CanGoOnline,
            }, "", 200);
        }

        #endregion

        #region Admin

        private IQueryable<ApplicationUser> DriversQuery() =>
            from u in _context.Users
            join ur in _context.UserRoles on u.Id equals ur.UserId
            join r in _context.Roles on ur.RoleId equals r.Id
            where r.Name == "Driver"
            select u;

        public async Task<Response<FinanceOverviewDTO>> GetOverviewAsync()
        {
            var rule = await GetRuleAsync();
            var balances = await _context.DriverLedgerEntries
                .GroupBy(e => e.DriverId)
                .Select(g => g.Sum(e => e.Amount))
                .ToListAsync();

            var now = Now;
            var monthStart = new DateTime(now.Year, now.Month, 1);
            var monthRows = await _context.DriverLedgerEntries
                .Where(e => e.CreatedAt >= monthStart)
                .Select(e => new { e.Type, e.Amount })
                .ToListAsync();

            // Commission earned this month = final state of trips that ended this month.
            var tripRows = await _context.DriverLedgerEntries
                .Where(e => e.TripId != null && e.Trip!.EndTime >= monthStart)
                .Select(e => new TripEntryRow(e.Id, e.TripId!, e.Type, e.Amount, e.TripFare,
                    e.CommissionAmount, e.CreatedAt, e.Trip!.EndTime))
                .ToListAsync();

            var warnDebt = rule.CashLimit * rule.WarningPercent / 100m;
            return Response<FinanceOverviewDTO>.Success(new FinanceOverviewDTO
            {
                TotalOwedToCompany = balances.Where(b => b < 0).Sum(b => -b),
                TotalOwedToDrivers = balances.Where(b => b > 0).Sum(),
                LockedDrivers = rule.CashLimit > 0 ? balances.Count(b => -b >= rule.CashLimit) : 0,
                NearLimitDrivers = rule.CashLimit > 0 ? balances.Count(b => -b >= warnDebt && -b < rule.CashLimit) : 0,
                DriversAwaitingPayout = balances.Count(b => b > 0),
                SettledThisMonth = monthRows.Where(r => r.Type is LedgerEntryType.Settlement or LedgerEntryType.WalletCollection).Sum(r => r.Amount),
                PaidOutThisMonth = -monthRows.Where(r => r.Type == LedgerEntryType.Payout).Sum(r => r.Amount),
                CommissionThisMonth = FinalTripEntries(tripRows).Sum(r => r.Commission ?? 0),
            }, "", 200);
        }

        public async Task<Response<PaginationPagedResponse<AdminDriverFinanceRowDTO>>> GetDriversAsync(PaginationRequest pagination, string? search, string? filter)
        {
            var page = Math.Max(1, pagination.PageNumber);
            var size = Math.Clamp(pagination.PageSize, 1, 100);
            var rule = await GetRuleAsync();
            var limit = rule.CashLimit;
            var warnDebt = limit * rule.WarningPercent / 100m;

            var query = DriversQuery().Select(u => new
            {
                User = u,
                Balance = _context.DriverLedgerEntries.Where(e => e.DriverId == u.Id).Sum(e => (decimal?)e.Amount) ?? 0,
                LastEntryAt = _context.DriverLedgerEntries.Where(e => e.DriverId == u.Id).Max(e => (DateTime?)e.CreatedAt),
            });

            if (!string.IsNullOrWhiteSpace(search))
            {
                var s = search.Trim();
                query = query.Where(x => x.User.FullName.Contains(s) || (x.User.PhoneNumber != null && x.User.PhoneNumber.Contains(s)));
            }

            switch (filter?.ToLowerInvariant())
            {
                case "locked":
                    query = limit > 0 ? query.Where(x => -x.Balance >= limit) : query.Where(x => false);
                    break;
                case "near":
                    query = limit > 0 ? query.Where(x => -x.Balance >= warnDebt && -x.Balance < limit) : query.Where(x => false);
                    break;
                case "owes":
                    query = query.Where(x => x.Balance < 0);
                    break;
                case "owed":
                    query = query.Where(x => x.Balance > 0);
                    break;
                case "collection":
                    var tolerance = rule.CollectionTolerance;
                    query = query.Where(x => x.User.CollectionLockedAt != null && -x.Balance > tolerance);
                    break;
            }

            var total = await query.CountAsync();
            var rows = await query
                .OrderBy(x => x.Balance).ThenBy(x => x.User.FullName)
                .Skip((page - 1) * size).Take(size)
                .ToListAsync();

            var items = rows.Select(x => new AdminDriverFinanceRowDTO
            {
                DriverId = x.User.Id,
                Name = x.User.FullName,
                Phone = x.User.PhoneNumber,
                ProfilePicture = x.User.ProfilePicture,
                Balance = x.Balance,
                IsLocked = limit > 0 && -x.Balance >= limit,
                IsNearLimit = limit > 0 && -x.Balance >= warnDebt && -x.Balance < limit,
                CollectionLocked = rule.CollectionEnabled && x.User.CollectionLockedAt != null && -x.Balance > rule.CollectionTolerance,
                IsAvailable = x.User.IsAvailable == true,
                VerificationStatus = x.User.VerificationStatus.ToString(),
                PayoutMethod = x.User.PayoutMethod?.ToString(),
                PayoutAccount = x.User.PayoutAccount,
                PayoutAccountName = x.User.PayoutAccountName,
                LastEntryAt = x.LastEntryAt,
            }).ToList();

            return Response<PaginationPagedResponse<AdminDriverFinanceRowDTO>>.Success(
                new PaginationPagedResponse<AdminDriverFinanceRowDTO>(items, total, page, size), "", 200);
        }

        private async Task<bool> IsDriverAsync(string driverId) =>
            await DriversQuery().AnyAsync(u => u.Id == driverId);

        private async Task<LedgerEntryDTO> ToDtoAsync(long entryId) =>
            (await _context.DriverLedgerEntries.IgnoreQueryFilters().Where(e => e.Id == entryId)
                .Select(e => new LedgerEntryDTO
                {
                    Id = e.Id,
                    Type = e.Type.ToString(),
                    Amount = e.Amount,
                    Description = e.Description,
                    Reference = e.Reference,
                    AttachmentUrl = e.AttachmentUrl != null ? "DriverFinance/ledger/" + e.Id + "/attachment" : null,
                    CreatedAt = e.CreatedAt,
                }).FirstAsync());

        public async Task<Response<LedgerEntryDTO>> AddAdjustmentAsync(string driverId, AdjustmentRequestDTO dto, string actorUserId)
        {
            var amount = Money(dto.Amount);
            var reason = (dto.Reason ?? string.Empty).Trim();
            if (amount == 0 || Math.Abs(amount) > 100_000)
                return Response<LedgerEntryDTO>.Failure("المبلغ غير صالح", 400);
            if (reason.Length < 3)
                return Response<LedgerEntryDTO>.Failure("سبب التسوية مطلوب", 400);
            if (!await IsDriverAsync(driverId))
                return Response<LedgerEntryDTO>.Failure("الكابتن غير موجود", 404);

            var (entryId, before, after) = await InDriverLockAsync(driverId, async () =>
            {
                var balance = await SumBalanceAsync(driverId);
                var entry = new DriverLedgerEntry
                {
                    DriverId = driverId,
                    Type = LedgerEntryType.Adjustment,
                    Amount = amount,
                    Description = reason,
                    CreatedByUserId = actorUserId,
                    CreatedAt = Now,
                };
                _context.DriverLedgerEntries.Add(entry);
                await _context.SaveChangesAsync();
                return (entry.Id, balance, balance + amount);
            });

            await WriteAuditAsync(actorUserId, "LedgerAdjustment", driverId, $"{amount:0.##} EGP — {reason}");
            await AfterBalanceChangedAsync(driverId, before, after);
            await SafeNotifyAsync(driverId, amount > 0 ? "إضافة لرصيدك" : "خصم من رصيدك",
                $"{(amount > 0 ? "اتضاف" : "اتخصم")} {Math.Abs(amount):0.##} ج.م: {reason}", "driver_ledger_adjustment");
            await EnforceEligibilityAsync(driverId);

            return Response<LedgerEntryDTO>.Success(await ToDtoAsync(entryId), "تم تسجيل التسوية", 201);
        }

        public async Task<Response<LedgerEntryDTO>> RecordPayoutAsync(string driverId, PayoutRequestDTO dto, string? attachmentUrl, string actorUserId)
        {
            var amount = Money(dto.Amount);
            var reference = (dto.Reference ?? string.Empty).Trim();
            if (amount <= 0)
                return Response<LedgerEntryDTO>.Failure("مبلغ التحويل لازم يكون أكبر من صفر", 400);
            if (reference.Length < 3)
                return Response<LedgerEntryDTO>.Failure("رقم مرجع التحويل مطلوب", 400);

            var driver = await _context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == driverId);
            if (driver == null || !await IsDriverAsync(driverId))
                return Response<LedgerEntryDTO>.Failure("الكابتن غير موجود", 404);

            var outcome = await InDriverLockAsync(driverId, async () =>
            {
                var balance = await SumBalanceAsync(driverId);
                if (amount > balance)
                    return (Error: $"المبلغ أكبر من مستحقات الكابتن ({balance:0.##} ج.م)", Id: 0L, Before: balance, After: balance);

                var destination = driver.PayoutAccount == null ? "" : $" إلى {driver.PayoutMethod} {driver.PayoutAccount}";
                var entry = new DriverLedgerEntry
                {
                    DriverId = driverId,
                    Type = LedgerEntryType.Payout,
                    Amount = -amount,
                    Reference = reference,
                    AttachmentUrl = attachmentUrl,
                    Description = $"تحويل أرباح{destination}" + (string.IsNullOrWhiteSpace(dto.Note) ? "" : $" — {dto.Note!.Trim()}"),
                    CreatedByUserId = actorUserId,
                    CreatedAt = Now,
                };
                _context.DriverLedgerEntries.Add(entry);
                await _context.SaveChangesAsync();
                return (Error: (string?)null, Id: entry.Id, Before: balance, After: balance - amount);
            });

            if (outcome.Error != null)
                return Response<LedgerEntryDTO>.Failure(outcome.Error, 400);

            await WriteAuditAsync(actorUserId, "PayoutRecorded", driverId, $"{amount:0.##} EGP ref={reference}");
            await AfterBalanceChangedAsync(driverId, outcome.Before, outcome.After, warn: false);
            await SafeNotifyAsync(driverId, "تم تحويل أرباحك 💸",
                $"حوّلنا لك {amount:0.##} ج.م (مرجع {reference}).", "driver_payout_sent");

            return Response<LedgerEntryDTO>.Success(await ToDtoAsync(outcome.Id), "تم تسجيل التحويل", 201);
        }

        public async Task<Response<PaginationPagedResponse<SettlementRowDTO>>> GetSettlementsAsync(PaginationRequest pagination, string? status)
        {
            var page = Math.Max(1, pagination.PageNumber);
            var size = Math.Clamp(pagination.PageSize, 1, 100);

            var query = _context.Payments.AsNoTracking().Where(p => p.Purpose == PaymentPurpose.DriverSettlement);
            if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<PaymentStatus>(status, true, out var st))
                query = query.Where(p => p.Status == st);

            var total = await query.CountAsync();
            var items = await query
                .OrderByDescending(p => p.CreatedAt)
                .Skip((page - 1) * size).Take(size)
                .Select(p => new SettlementRowDTO
                {
                    PaymentId = p.Id,
                    DriverId = p.UserId,
                    DriverName = p.User.FullName,
                    DriverPhone = p.User.PhoneNumber,
                    Amount = p.Amount,
                    Status = p.Status.ToString(),
                    Credited = _context.DriverLedgerEntries.Any(e => e.PaymentId == p.Id),
                    Method = p.Method,
                    TransactionId = p.TransactionId,
                    CreatedAt = p.CreatedAt,
                    UpdatedAt = p.UpdatedAt,
                })
                .ToListAsync();

            return Response<PaginationPagedResponse<SettlementRowDTO>>.Success(
                new PaginationPagedResponse<SettlementRowDTO>(items, total, page, size), "", 200);
        }

        public async Task<Response<PaginationPagedResponse<AuditLogDTO>>> GetAuditLogAsync(PaginationRequest pagination, string? targetUserId)
        {
            var page = Math.Max(1, pagination.PageNumber);
            var size = Math.Clamp(pagination.PageSize, 1, 100);

            var query = _context.AdminAuditLogs.AsNoTracking().AsQueryable();
            if (!string.IsNullOrWhiteSpace(targetUserId))
                query = query.Where(a => a.TargetUserId == targetUserId);

            var total = await query.CountAsync();
            var items = await query
                .OrderByDescending(a => a.Id)
                .Skip((page - 1) * size).Take(size)
                .Select(a => new AuditLogDTO
                {
                    Id = a.Id,
                    ActorUserId = a.ActorUserId,
                    ActorName = a.ActorName,
                    Action = a.Action,
                    TargetUserId = a.TargetUserId,
                    TargetName = a.TargetUserId == null ? null
                        : _context.Users.IgnoreQueryFilters().Where(u => u.Id == a.TargetUserId).Select(u => u.FullName).FirstOrDefault(),
                    Details = a.Details,
                    CreatedAt = a.CreatedAt,
                })
                .ToListAsync();

            return Response<PaginationPagedResponse<AuditLogDTO>>.Success(
                new PaginationPagedResponse<AuditLogDTO>(items, total, page, size), "", 200);
        }

        public async Task WriteAuditAsync(string actorUserId, string action, string? targetUserId, string? details)
        {
            try
            {
                var actorName = await _context.Users.IgnoreQueryFilters().AsNoTracking()
                    .Where(u => u.Id == actorUserId).Select(u => u.FullName).FirstOrDefaultAsync();
                _context.AdminAuditLogs.Add(new AdminAuditLog
                {
                    ActorUserId = actorUserId,
                    ActorName = actorName,
                    Action = action,
                    TargetUserId = targetUserId,
                    Details = details,
                    CreatedAt = Now,
                });
                await _context.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Audit log write failed for {Action}", action);
            }
        }

        #endregion
    }
}
