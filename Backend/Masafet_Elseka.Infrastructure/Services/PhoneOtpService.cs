using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using Masafet_Elseka.Application.DTOs.Collection;
using Masafet_Elseka.Application.Interfaces;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Infrastructure.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace Masafet_Elseka.Infrastructure.Services
{
    public class PhoneOtpService : IPhoneOtpService
    {
        private readonly Context _context;
        private readonly UserManager<ApplicationUser> _users;
        private readonly byte[] _hmacKey;
        private static DateTime Now => DateTime.Now.ToEgyptTime();

        public PhoneOtpService(Context context, UserManager<ApplicationUser> users, IConfiguration config)
        {
            _context = context;
            _users = users;
            var secret = config["JWT:Key"] ?? throw new InvalidOperationException("JWT Key not found in Config");
            _hmacKey = HMACSHA256.HashData(Encoding.UTF8.GetBytes(secret),
                Encoding.UTF8.GetBytes("VGo.PhoneResetOtp.v1"));
        }

        private string Hash(string value) =>
            Convert.ToHexString(HMACSHA256.HashData(_hmacKey, Encoding.UTF8.GetBytes(value)));

        // Transaction-owned SQL Server locks also coordinate multiple API instances.
        // Request/verify/reset share a lock so limits and single-use credentials cannot race.
        private Task LockAsync(string resource) => _context.Database.ExecuteSqlInterpolatedAsync($@"
            DECLARE @result int;
            EXEC @result = sys.sp_getapplock @Resource = {resource},
                @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 15000;
            IF @result < 0 THROW 50001, 'Unable to acquire OTP lock', 1;");

        public async Task<Response<object>> RequestAsync(string? phone)
        {
            var normalized = AuthService.AuthService.NormalizePhone(phone ?? string.Empty);
            await using var transaction = await _context.Database.BeginTransactionAsync();
            await LockAsync("VGo.PhoneResetOtp");
            await LockAsync("VGo.SmsOutbox");
            var now = Now;
            var user = await _users.Users.FirstOrDefaultAsync(u => u.PhoneNumber == normalized);
            if (user == null)
                return Response<object>.Failure("لا يوجد حساب بهذا الرقم", 404, code: "NO_ACCOUNT");

            var requests = _context.PhoneOtps.Where(o => o.Phone == normalized && o.Purpose == "reset");
            var latest = await requests.OrderByDescending(o => o.CreatedAt).FirstOrDefaultAsync();
            if (latest != null && latest.CreatedAt > now.AddSeconds(-60))
                return Response<object>.Failure(new { cooldownSeconds = (int)Math.Ceiling((latest.CreatedAt.AddSeconds(60) - now).TotalSeconds) },
                    "انتظر قليلًا قبل طلب رمز جديد", 429, code: "COOLDOWN");
            if (await requests.CountAsync(o => o.CreatedAt > now.AddHours(-1)) >= 5)
                return Response<object>.Failure("محاولات كثيرة، حاول بعد ساعة", 429, code: "TOO_MANY");
            if (await _context.SmsOutbox.CountAsync(s => s.Purpose == "reset" && s.CreatedAt >= now.Date) >= 300)
                return Response<object>.Failure("خدمة الرسائل مشغولة حاليًا، حاول لاحقًا أو تواصل مع الدعم", 503, code: "SMS_DAILY_LIMIT");
            if (!await _context.CollectorDevices.AnyAsync(d => d.IsActive && d.KeyHash != null && d.LastSeenAt >= now.AddMinutes(-3)))
                return Response<object>.Failure("خدمة الرسائل غير متاحة حاليًا، حاول بعد قليل أو تواصل مع الدعم", 503, code: "SMS_OFFLINE");

            await requests.Where(o => o.ConsumedAt == null)
                .ExecuteUpdateAsync(s => s.SetProperty(o => o.ConsumedAt, now));
            // Do not deliver a superseded code that is still waiting in the queue.
            await _context.SmsOutbox.Where(s => s.To == normalized && s.Purpose == "reset" && s.Status == "Pending")
                .ExecuteUpdateAsync(s => s.SetProperty(o => o.Status, "Expired"));

            var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6", CultureInfo.InvariantCulture);
            var otp = new PhoneOtp
            {
                Id = Guid.NewGuid(), UserId = user.Id, Phone = normalized,
                CreatedAt = now, ExpiresAt = now.AddMinutes(5),
            };
            otp.CodeHash = Hash($"code:{otp.Id:N}:{code}");
            _context.PhoneOtps.Add(otp);
            _context.SmsOutbox.Add(new SmsOutbox
            {
                Id = Guid.NewGuid(), To = normalized,
                Body = $"V.Go: كود تغيير كلمة السر {code}\nصالح 5 دقائق ولا تشاركه مع أحد",
                CreatedAt = now, ExpiresAt = otp.ExpiresAt,
            });
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            return Response<object>.Success(new { expiresInSeconds = 300, cooldownSeconds = 60 }, "تم إرسال رمز التحقق");
        }

        public async Task<Response<object>> VerifyAsync(string? phone, string? code)
        {
            var normalized = AuthService.AuthService.NormalizePhone(phone ?? string.Empty);
            await using var transaction = await _context.Database.BeginTransactionAsync();
            await LockAsync("VGo.PhoneResetOtp");
            var now = Now;
            var otp = await _context.PhoneOtps.Where(o => o.Phone == normalized && o.Purpose == "reset")
                .OrderByDescending(o => o.CreatedAt).FirstOrDefaultAsync();
            if (otp == null || otp.ExpiresAt <= now)
                return Response<object>.Failure("انتهت صلاحية الرمز، اطلب رمزًا جديدًا", 400, code: "CODE_EXPIRED");
            if (otp.Attempts >= 5)
                return Response<object>.Failure("محاولات كثيرة، اطلب رمزًا جديدًا", 429, code: "TOO_MANY_ATTEMPTS");
            if (otp.ConsumedAt != null)
                return Response<object>.Failure("انتهت صلاحية الرمز، اطلب رمزًا جديدًا", 400, code: "CODE_EXPIRED");

            var actual = Hash($"code:{otp.Id:N}:{code ?? string.Empty}");
            if (!CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(otp.CodeHash), Encoding.ASCII.GetBytes(actual)))
            {
                otp.Attempts++;
                if (otp.Attempts >= 5) otp.ConsumedAt = now;
                await _context.SaveChangesAsync();
                await transaction.CommitAsync();
                return otp.Attempts >= 5
                    ? Response<object>.Failure("محاولات كثيرة، اطلب رمزًا جديدًا", 429, code: "TOO_MANY_ATTEMPTS")
                    : Response<object>.Failure(new { attemptsLeft = 5 - otp.Attempts }, "رمز التحقق غير صحيح", 400, code: "INVALID_CODE");
            }

            var token = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32))
                .TrimEnd('=').Replace('+', '-').Replace('/', '_');
            otp.ConsumedAt = now;
            otp.ResetTokenHash = Hash("token:" + token);
            otp.ResetTokenExpiresAt = now.AddMinutes(10);
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            return Response<object>.Success(new { resetToken = token, expiresInSeconds = 600 });
        }

        public async Task<Response<string>> ResetPasswordAsync(string resetToken, string? newPassword)
        {
            await using var transaction = await _context.Database.BeginTransactionAsync();
            await LockAsync("VGo.PhoneResetOtp");
            var now = Now;
            var hash = Hash("token:" + resetToken);
            var otp = await _context.PhoneOtps.FirstOrDefaultAsync(o => o.Purpose == "reset" &&
                o.ResetTokenHash == hash && o.ResetTokenExpiresAt > now && o.ResetTokenUsedAt == null && o.ConsumedAt != null);
            if (otp == null)
                return Response<string>.Failure("انتهت صلاحية الجلسة، أعد المحاولة", 401);
            var user = await _users.FindByIdAsync(otp.UserId);
            if (user == null)
                return Response<string>.Failure("انتهت صلاحية الجلسة، أعد المحاولة", 401);
            if (string.IsNullOrWhiteSpace(newPassword))
                return Response<string>.Failure("كلمة المرور الجديدة مطلوبة", 400);

            IdentityResult result;
            if (await _users.HasPasswordAsync(user))
            {
                var identityToken = await _users.GeneratePasswordResetTokenAsync(user);
                result = await _users.ResetPasswordAsync(user, identityToken, newPassword);
            }
            else
                result = await _users.AddPasswordAsync(user, newPassword);
            if (!result.Succeeded)
            {
                var error = string.Join(" ", result.Errors.Select(e => e.Description));
                return Response<string>.Failure(string.IsNullOrWhiteSpace(error) ? "تعذّر تعيين كلمة المرور" : error, 400);
            }
            otp.ResetTokenUsedAt = now;
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            return Response<string>.Success("تم تعيين كلمة المرور بنجاح", "تم تعيين كلمة المرور بنجاح");
        }

        public async Task<List<SmsOutboxMessageDTO>> ClaimOutboxAsync(Guid deviceId, int max)
        {
            await using var transaction = await _context.Database.BeginTransactionAsync();
            await LockAsync("VGo.SmsOutbox");
            var now = Now;
            var leaseCutoff = now.AddSeconds(-60);
            await _context.CollectorDevices.Where(d => d.Id == deviceId)
                .ExecuteUpdateAsync(s => s.SetProperty(d => d.LastSeenAt, now));
            await _context.SmsOutbox.Where(s => (s.Status == "Pending" || s.Status == "Claimed") &&
                (s.ExpiresAt <= now || s.Attempts >= 3))
                .ExecuteUpdateAsync(s => s.SetProperty(o => o.Status, "Expired"));

            var limit = Math.Clamp(max, 1, 10);
            // Update locks prevent a late result from changing a selected row before it is reclaimed.
            var messages = await _context.SmsOutbox.FromSqlInterpolated($@"
                SELECT TOP ({limit}) * FROM [SmsOutbox] WITH (UPDLOCK, HOLDLOCK)
                WHERE ([Status] = 'Pending' OR ([Status] = 'Claimed' AND [ClaimedAt] < {leaseCutoff}))
                  AND [ExpiresAt] > {now} AND [Attempts] < 3
                ORDER BY [CreatedAt], [Id]").ToListAsync();
            foreach (var message in messages)
            {
                message.Status = "Claimed";
                message.ClaimedByDeviceId = deviceId;
                message.ClaimedAt = now;
                message.Attempts++;
            }
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            return messages.Select(s => new SmsOutboxMessageDTO { Id = s.Id, To = s.To, Body = s.Body }).ToList();
        }

        public async Task<Response<string>> ReportOutboxAsync(Guid deviceId, Guid id, SmsOutboxResultDTO result)
        {
            var now = Now;
            var error = result.Error == null ? null : result.Error[..Math.Min(300, result.Error.Length)];
            var claimed = _context.SmsOutbox.Where(s => s.Id == id && s.Status == "Claimed" && s.ClaimedByDeviceId == deviceId);
            var changed = result.Sent
                ? await claimed.ExecuteUpdateAsync(s => s.SetProperty(o => o.Status, "Sent")
                    .SetProperty(o => o.SentAt, now).SetProperty(o => o.Error, (string?)null))
                : await claimed.ExecuteUpdateAsync(s => s.SetProperty(o => o.Status, o => o.Attempts >= 3 ? "Failed" : "Pending")
                    .SetProperty(o => o.Error, error));
            if (changed == 0)
            {
                // A result retry after a lost HTTP response is harmless; another device is never accepted.
                var acknowledged = await _context.SmsOutbox.AnyAsync(s => s.Id == id && s.ClaimedByDeviceId == deviceId &&
                    (result.Sent ? s.Status == "Sent" : (s.Status == "Pending" || s.Status == "Failed")));
                if (!acknowledged) return Response<string>.Failure("الرسالة غير محجوزة لهذا الجهاز", 409);
            }
            return Response<string>.Success(string.Empty);
        }
    }
}
