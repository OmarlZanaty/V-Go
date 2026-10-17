using System.ComponentModel.DataAnnotations;
using System.Globalization;
using System.Net.Mail;
using Masafet_Elseka.Application.DTOs.Beta;
using Masafet_Elseka.Application.Interfaces.IBetaService;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Masafet_Elseka.Infrastructure.Services.BetaService
{
    public class BetaService(Context db, IBetaGoogleTokenVerifier google, BetaOptions options,
        TimeProvider clock, ILogger<BetaService> logger) : IBetaService
    {
        public const string HeartbeatKey = "beta_sync_last_poll";
        public const string OutageAlertKey = "beta_sync_outage_alerted";
        public const string RejectedMarker = "not_a_google_account";

        public static string NormalizeEmail(string? email)
        {
            var normalized = email?.Trim().ToLowerInvariant() ?? string.Empty;
            if (normalized.Length > 254 || !new EmailAddressAttribute().IsValid(normalized)
                || !MailAddress.TryCreate(normalized, out var address) || address.Address != normalized)
                throw new BetaRequestException(400, "A valid email is required.");
            return normalized;
        }

        public async Task<BetaEnrollResponse> EnrollAsync(BetaEnrollRequest request, CancellationToken ct = default)
        {
            // Even an empty supplied token must be verified/rejected, never fall back to client email.
            var identity = request.IdToken != null ? await google.VerifyAsync(request.IdToken, ct) : null;
            var email = NormalizeEmail(identity?.Email ?? request.Email);
            var source = string.IsNullOrWhiteSpace(request.Source) ? "landing" : request.Source.Trim();
            if (source.Length > 40) throw new BetaRequestException(400, "Source is too long.");
            var tester = await db.BetaTesters.SingleOrDefaultAsync(t => t.Email == email, ct);
            var alreadyEnrolled = tester != null;
            if (tester == null)
            {
                tester = new BetaTester { Email = email, Source = source, EnrolledAt = clock.GetUtcNow().UtcDateTime };
                db.BetaTesters.Add(tester);
            }
            Requeue(tester);
            if (identity != null) tester.GoogleSub = identity.Subject;
            try
            {
                await db.SaveChangesAsync(ct);
            }
            catch (DbUpdateException ex) when (!alreadyEnrolled && ex.InnerException is SqlException { Number: 2601 or 2627 })
            {
                // Two simultaneous first signups must still behave as an upsert.
                db.Entry(tester).State = EntityState.Detached;
                tester = await db.BetaTesters.SingleAsync(t => t.Email == email, ct);
                alreadyEnrolled = true;
                Requeue(tester);
                if (identity != null) tester.GoogleSub = identity.Subject;
                await db.SaveChangesAsync(ct);
            }
            var health = await DaemonHealthAsync(ct);
            return new BetaEnrollResponse(false, !health.Online, StatusName(tester.Status),
                alreadyEnrolled, options.PlayUrl, options.ApkUrl);
        }

        private static void Requeue(BetaTester tester)
        {
            tester.PlaySynced = false;
            tester.PlayError = null; // Includes the rejection marker: the visitor explicitly asked to retry.
            tester.SyncAttempts = 0;
            if (tester.Status == BetaTesterStatus.Dropped) tester.Status = BetaTesterStatus.Invited;
        }

        public async Task<BetaEnrollStatus> EnrollStatusAsync(string email, CancellationToken ct = default)
        {
            email = NormalizeEmail(email);
            var tester = await db.BetaTesters.AsNoTracking().SingleOrDefaultAsync(t => t.Email == email, ct);
            var synced = tester?.PlaySynced ?? false;
            var rejected = !synced && tester?.PlayError == RejectedMarker;
            var delayed = tester != null && !synced && !rejected && !(await DaemonHealthAsync(ct)).Online;
            return new BetaEnrollStatus(tester != null, synced, rejected, delayed);
        }

        public async Task<BetaPendingResponse> PendingAsync(CancellationToken ct = default)
        {
            var testers = await db.BetaTesters.AsNoTracking()
                .Where(t => !t.PlaySynced && t.Status != BetaTesterStatus.Dropped
                    && (t.PlayError == null || t.PlayError != RejectedMarker))
                .OrderBy(t => t.EnrolledAt).ThenBy(t => t.Id).Take(100)
                .Select(t => new BetaPendingTester(t.Id, t.Email)).ToListAsync(ct);
            // Fetch first so even a failed heartbeat connection cannot spoil a fetched queue.
            await StampHeartbeatAsync(ct);
            return new BetaPendingResponse(testers);
        }

        private async Task StampHeartbeatAsync(CancellationToken ct)
        {
            AppSetting? setting = null;
            AppSetting? alert = null;
            try
            {
                setting = await db.AppSettings.FindAsync(new object[] { HeartbeatKey }, ct);
                if (setting == null)
                {
                    setting = new AppSetting { Key = HeartbeatKey };
                    db.AppSettings.Add(setting);
                }
                var now = clock.GetUtcNow();
                setting.Value = now.ToString("O", CultureInfo.InvariantCulture);
                setting.UpdatedAt = now.UtcDateTime;
                // Observe recovery even if it happens between watchdog ticks.
                alert = await db.AppSettings.FindAsync(new object[] { OutageAlertKey }, ct);
                if (alert?.Value == "true")
                {
                    alert.Value = "false";
                    alert.UpdatedAt = now.UtcDateTime;
                }
                await db.SaveChangesAsync(ct);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                // Do not leave a failed write tracked for a later SaveChanges in this scope.
                if (setting != null) db.Entry(setting).State = EntityState.Detached;
                if (alert != null) db.Entry(alert).State = EntityState.Detached;
                logger.LogWarning("Beta sync heartbeat stamp failed ({ErrorType}).", ex.GetType().Name);
            }
        }

        public async Task<BetaDaemonHealth> DaemonHealthAsync(CancellationToken ct = default)
        {
            var value = await db.AppSettings.AsNoTracking().Where(s => s.Key == HeartbeatKey)
                .Select(s => s.Value).SingleOrDefaultAsync(ct);
            DateTimeOffset? last = DateTimeOffset.TryParse(value, CultureInfo.InvariantCulture,
                DateTimeStyles.AssumeUniversal, out var parsed) ? parsed : null;
            return new BetaDaemonHealth(last.HasValue && clock.GetUtcNow() - last.Value <= TimeSpan.FromSeconds(90), last);
        }

        public async Task<int> SyncDoneAsync(string[] ids, CancellationToken ct = default)
        {
            if (ids.Length is < 1 or > 100 || ids.Any(id => string.IsNullOrWhiteSpace(id) || id.Length > 32))
                throw new BetaRequestException(400, "Provide between 1 and 100 valid string IDs.");
            var testers = await db.BetaTesters.Where(t => ids.Contains(t.Id)).ToListAsync(ct);
            foreach (var tester in testers)
            {
                tester.PlaySynced = true;
                tester.PlayError = null;
                tester.SyncAttempts++;
                tester.LastCheckedAt = clock.GetUtcNow().UtcDateTime;
            }
            await db.SaveChangesAsync(ct);
            return testers.Count;
        }

        public async Task<bool> SyncFailedAsync(BetaSyncFailedRequest request, CancellationToken ct = default)
        {
            var tester = await db.BetaTesters.FindAsync(new object[] { request.Id }, ct);
            if (tester == null) return false;
            tester.PlaySynced = false;
            // Legacy {id,reason} means rejected per PORTING.md. The current daemon
            // explicitly sends false for automation failures; those remain retryable.
            tester.PlayError = request.Refused != false ? RejectedMarker
                : string.IsNullOrWhiteSpace(request.Reason) || request.Reason == RejectedMarker
                    ? "sync failed" : request.Reason;
            tester.SyncAttempts++;
            tester.LastCheckedAt = clock.GetUtcNow().UtcDateTime;
            await db.SaveChangesAsync(ct);
            return true;
        }

        public async Task<BetaStatusResponse> StatusAsync(CancellationToken ct = default)
        {
            var counts = await db.BetaTesters.GroupBy(t => t.Status)
                .Select(g => new { Status = g.Key, Count = g.Count() }).ToDictionaryAsync(g => g.Status, g => g.Count, ct);
            var synced = await db.BetaTesters.CountAsync(t => t.PlaySynced, ct);
            var health = await DaemonHealthAsync(ct);
            return new BetaStatusResponse(counts.GetValueOrDefault(BetaTesterStatus.Invited),
                counts.GetValueOrDefault(BetaTesterStatus.OptedIn), counts.GetValueOrDefault(BetaTesterStatus.Installed),
                counts.GetValueOrDefault(BetaTesterStatus.Dropped), synced, options.TargetTesters, health.Online, health.LastPoll);
        }

        public async Task<BetaTestersPage> TestersAsync(int page, int pageSize, CancellationToken ct = default)
        {
            if (page < 1 || pageSize is < 1 or > 100 || (long)(page - 1) * pageSize > int.MaxValue)
                throw new BetaRequestException(400, "Page must be positive and pageSize between 1 and 100.");
            var total = await db.BetaTesters.CountAsync(ct);
            var testers = await db.BetaTesters.AsNoTracking().OrderByDescending(t => t.EnrolledAt).ThenBy(t => t.Id)
                .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
            return new BetaTestersPage(testers.Select(t => new BetaTesterDTO(t.Id, t.Email, t.GoogleSub, t.Source,
                StatusName(t.Status), t.PlaySynced, t.PlayError, t.SyncAttempts, t.EnrolledAt, t.LastCheckedAt, t.RemindedAt))
                .ToList(), total, page, pageSize);
        }

        public async Task<bool> SetStatusAsync(string id, string status, CancellationToken ct = default)
        {
            var value = status switch
            {
                "invited" => BetaTesterStatus.Invited,
                "opted_in" => BetaTesterStatus.OptedIn,
                "installed" => BetaTesterStatus.Installed,
                "dropped" => BetaTesterStatus.Dropped,
                _ => throw new BetaRequestException(400, "Invalid tester status.")
            };
            var tester = await db.BetaTesters.FindAsync(new object[] { id }, ct);
            if (tester == null) return false;
            tester.Status = value;
            tester.LastCheckedAt = clock.GetUtcNow().UtcDateTime;
            await db.SaveChangesAsync(ct);
            return true;
        }

        public async Task<bool> RetrySyncAsync(string id, CancellationToken ct = default)
        {
            var tester = await db.BetaTesters.FindAsync(new object[] { id }, ct);
            if (tester == null) return false;
            Requeue(tester);
            await db.SaveChangesAsync(ct);
            return true;
        }

        private static string StatusName(BetaTesterStatus status) => status switch
        {
            BetaTesterStatus.OptedIn => "opted_in",
            BetaTesterStatus.Installed => "installed",
            BetaTesterStatus.Dropped => "dropped",
            _ => "invited"
        };
    }
}
