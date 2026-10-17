using Hangfire;
using Masafet_Elseka.Application.DTOs.PushFireBaseNotificationMessage;
using Masafet_Elseka.Application.ExternalInterfaces.IFirebaseNotificationService;
using Masafet_Elseka.Application.Interfaces.IBetaService;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Masafet_Elseka.Infrastructure.Services.BetaService
{
    public class BetaSyncWatchdog(Context db, IBetaService beta, IFirebaseNotificationService push,
        TimeProvider clock, ILogger<BetaSyncWatchdog> logger)
    {

        // Shared Hangfire storage serializes this job across application instances.
        // Persisting the flag also prevents a restart from repeating the outage push.
        [DisableConcurrentExecution(60)]
        [AutomaticRetry(Attempts = 0)]
        public async Task CheckAsync(CancellationToken ct = default)
        {
            var health = await beta.DaemonHealthAsync(ct);
            var flag = await db.AppSettings.FindAsync(new object[] { BetaService.OutageAlertKey }, ct);
            if (health.Online)
            {
                if (flag?.Value == "true")
                {
                    flag.Value = "false";
                    flag.UpdatedAt = clock.GetUtcNow().UtcDateTime;
                    await db.SaveChangesAsync(ct);
                }
                return;
            }
            if (flag?.Value == "true") return;
            if (flag == null)
            {
                flag = new AppSetting { Key = BetaService.OutageAlertKey };
                db.AppSettings.Add(flag);
            }
            // At most one notification attempt per outage, including push failures.
            flag.Value = "true";
            flag.UpdatedAt = clock.GetUtcNow().UtcDateTime;
            await db.SaveChangesAsync(ct);
            logger.LogWarning("Beta sync daemon is offline; last poll: {LastPoll}.", health.LastPoll);

            var adminIds = from userRole in db.UserRoles
                           join role in db.Roles on userRole.RoleId equals role.Id
                           where role.Name == "Admin"
                           select userRole.UserId;
            var tokens = await db.Set<UserDevice>().AsNoTracking()
                .Where(d => adminIds.Contains(d.UserId) && !d.User.IsDeleted
                    && d.IsActive && !d.IsDeletd && d.DeviceToken != null && d.DeviceToken != "")
                .Select(d => d.DeviceToken!).Distinct().ToListAsync(ct);
            var message = new PushFireBaseNotificationMessage
            {
                Title = "V.Go Captain beta sync offline",
                Body = "The beta sync daemon has not polled within 90 seconds. Check its host and Play Console session.",
                Data = new Dictionary<string, string> { ["type"] = "beta_sync_offline" }
            };
            foreach (var batch in tokens.Chunk(500))
            {
                try
                {
                    await push.SendToMultipleDevicesAsync(batch.ToList(), message, ct);
                }
                catch (Exception ex) when (ex is not OperationCanceledException)
                {
                    logger.LogWarning("Beta sync outage push failed ({ErrorType}).", ex.GetType().Name);
                }
            }
        }
    }
}
