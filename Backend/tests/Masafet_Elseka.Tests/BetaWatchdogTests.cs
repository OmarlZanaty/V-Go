using Masafet_Elseka.Application.DTOs.PushFireBaseNotificationMessage;
using Masafet_Elseka.Application.ExternalInterfaces.IFirebaseNotificationService;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Infrastructure.Services.BetaService;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Masafet_Elseka.Tests
{
    public class BetaWatchdogTests
    {
        private sealed class RecordingPush : IFirebaseNotificationService
        {
            public List<List<string>> Batches { get; } = [];
            public Task<IReadOnlyList<string>> SendToDeviceAsync(string token, PushFireBaseNotificationMessage message,
                CancellationToken ct = default) => SendToMultipleDevicesAsync(new List<string> { token }, message, ct);
            public Task<IReadOnlyList<string>> SendToMultipleDevicesAsync(List<string> tokens, PushFireBaseNotificationMessage message,
                CancellationToken ct = default)
            {
                Batches.Add(tokens);
                Assert.Equal("beta_sync_offline", message.Data!["type"]);
                return Task.FromResult<IReadOnlyList<string>>(Array.Empty<string>());
            }
        }

        [Fact]
        public async Task Sends_once_to_admins_per_outage_and_poll_recovery_resets_persisted_flag()
        {
            using var db = BetaServiceTests.NewDb();
            var admin = new ApplicationUser { Id = "admin", FullName = "Admin", Gender = "unspecified" };
            var rider = new ApplicationUser { Id = "rider", FullName = "Rider", Gender = "unspecified" };
            db.Users.AddRange(admin, rider);
            db.Roles.Add(new IdentityRole { Id = "admin-role", Name = "Admin", NormalizedName = "ADMIN" });
            db.UserRoles.Add(new IdentityUserRole<string> { UserId = admin.Id, RoleId = "admin-role" });
            db.Set<UserDevice>().AddRange(
                new UserDevice { UserId = admin.Id, DeviceToken = "test-admin-device", IsActive = true },
                new UserDevice { UserId = admin.Id, DeviceToken = "test-inactive-device", IsActive = false },
                new UserDevice { UserId = rider.Id, DeviceToken = "test-rider-device", IsActive = true });
            await db.SaveChangesAsync();
            var clock = new BetaServiceTests.TestClock();
            var beta = BetaServiceTests.Service(db, clock);
            var push = new RecordingPush();
            BetaSyncWatchdog Watchdog() => new(db, beta, push, clock, NullLogger<BetaSyncWatchdog>.Instance);
            await Watchdog().CheckAsync();
            await Watchdog().CheckAsync(); // New instance must still see the persisted flag.
            Assert.Single(push.Batches);
            Assert.Equal(new[] { "test-admin-device" }, push.Batches[0]);
            await beta.PendingAsync();
            Assert.Equal("false", (await db.AppSettings.SingleAsync(s => s.Key == BetaService.OutageAlertKey)).Value);
            await Watchdog().CheckAsync();
            Assert.Single(push.Batches);
            clock.Now = clock.Now.AddSeconds(91);
            await Watchdog().CheckAsync();
            await Watchdog().CheckAsync();
            Assert.Equal(2, push.Batches.Count);
        }
    }
}
