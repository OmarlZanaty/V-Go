using System.Globalization;
using Masafet_Elseka.Application.DTOs.Beta;
using Masafet_Elseka.Application.Interfaces.IBetaService;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Data;
using Masafet_Elseka.Infrastructure.Services.BetaService;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Masafet_Elseka.Tests
{
    public class BetaServiceTests
    {
        internal sealed class TestClock : TimeProvider
        {
            public DateTimeOffset Now { get; set; } = new(2026, 10, 17, 12, 0, 0, TimeSpan.Zero);
            public override DateTimeOffset GetUtcNow() => Now;
        }

        internal sealed class FakeGoogle : IBetaGoogleTokenVerifier
        {
            public Task<BetaGoogleIdentity> VerifyAsync(string token, CancellationToken ct = default)
                => token == "valid-test-token"
                    ? Task.FromResult(new BetaGoogleIdentity(" Verified@Gmail.com ", "google-sub"))
                    : throw new BetaRequestException(401, "Invalid token");
        }

        internal static Context NewDb(params IInterceptor[] interceptors) => new(
            new DbContextOptionsBuilder<Context>().UseInMemoryDatabase(Guid.NewGuid().ToString())
                .AddInterceptors(interceptors).Options);

        internal static BetaService Service(Context db, TimeProvider? clock = null) => new(
            db, new FakeGoogle(), new BetaOptions(), clock ?? new TestClock(), NullLogger<BetaService>.Instance);

        [Theory]
        [InlineData("  Test.Name+tag@GMAIL.com  ", "test.name+tag@gmail.com")]
        [InlineData("Person@Workspace.example", "person@workspace.example")]
        public async Task Enrollment_normalizes_email_without_changing_google_aliases(string email, string expected)
        {
            using var db = NewDb();
            var result = await Service(db).EnrollAsync(new BetaEnrollRequest { Email = email });
            Assert.Equal(expected, (await db.BetaTesters.SingleAsync()).Email);
            Assert.False(result.AlreadyEnrolled);
            Assert.False(result.PlaySynced);
        }

        [Theory]
        [InlineData("")]
        [InlineData("not-an-email")]
        [InlineData("User <person@gmail.com>")]
        public async Task Invalid_email_is_rejected(string email)
        {
            using var db = NewDb();
            var error = await Assert.ThrowsAsync<BetaRequestException>(() => Service(db)
                .EnrollAsync(new BetaEnrollRequest { Email = email }));
            Assert.Equal(400, error.StatusCode);
            Assert.Empty(db.BetaTesters);
        }

        [Theory]
        [InlineData(BetaTesterStatus.Installed, BetaTesterStatus.Installed)]
        [InlineData(BetaTesterStatus.Dropped, BetaTesterStatus.Invited)]
        public async Task Repeat_signup_requeues_clears_rejection_and_revives_dropped(
            BetaTesterStatus before, BetaTesterStatus after)
        {
            using var db = NewDb();
            var service = Service(db);
            await service.EnrollAsync(new BetaEnrollRequest { Email = "person@gmail.com" });
            var tester = await db.BetaTesters.SingleAsync();
            tester.Status = before;
            tester.PlaySynced = true;
            tester.PlayError = BetaService.RejectedMarker;
            tester.SyncAttempts = 3;
            await db.SaveChangesAsync();
            var result = await service.EnrollAsync(new BetaEnrollRequest { Email = " PERSON@GMAIL.COM " });
            Assert.True(result.AlreadyEnrolled);
            Assert.False(result.PlaySynced);
            Assert.Single(db.BetaTesters);
            Assert.Equal(after, tester.Status);
            Assert.Null(tester.PlayError);
            Assert.Equal(0, tester.SyncAttempts);
            Assert.Single((await service.PendingAsync()).Testers);
        }

        [Fact]
        public async Task Google_identity_overrides_client_email_and_invalid_token_never_falls_back()
        {
            using var db = NewDb();
            var service = Service(db);
            await service.EnrollAsync(new BetaEnrollRequest { Email = "ignored", IdToken = "valid-test-token" });
            var tester = await db.BetaTesters.SingleAsync();
            Assert.Equal("verified@gmail.com", tester.Email);
            Assert.Equal("google-sub", tester.GoogleSub);
            foreach (var token in new[] { "", "invalid" })
            {
                var error = await Assert.ThrowsAsync<BetaRequestException>(() => service.EnrollAsync(
                    new BetaEnrollRequest { Email = "other@gmail.com", IdToken = token }));
                Assert.Equal(401, error.StatusCode);
            }
            Assert.Single(db.BetaTesters);
        }

        [Fact]
        public async Task Pending_excludes_synced_dropped_and_rejected_orders_and_caps_at_100()
        {
            using var db = NewDb();
            var clock = new TestClock();
            for (var i = 0; i < 105; i++)
                db.BetaTesters.Add(new BetaTester { Email = $"person{i}@gmail.com", EnrolledAt = clock.Now.AddSeconds(i).UtcDateTime });
            db.BetaTesters.AddRange(
                new BetaTester { Email = "dropped@gmail.com", Status = BetaTesterStatus.Dropped },
                new BetaTester { Email = "rejected@gmail.com", PlayError = BetaService.RejectedMarker },
                new BetaTester { Email = "synced@gmail.com", PlaySynced = true });
            await db.SaveChangesAsync();
            var result = await Service(db, clock).PendingAsync();
            Assert.Equal(100, result.Testers.Count);
            Assert.Equal(Enumerable.Range(0, 100).Select(i => $"person{i}@gmail.com"), result.Testers.Select(t => t.Email));
            Assert.All(result.Testers, t => Assert.Equal(32, t.Id.Length));
            Assert.True((await Service(db, clock).DaemonHealthAsync()).Online);
        }

        [Theory]
        [InlineData(null, true)]
        [InlineData("invalid", true)]
        [InlineData("2026-10-17T11:58:29Z", true)]
        [InlineData("2026-10-17T11:58:30Z", false)]
        [InlineData("2026-10-17T12:00:00Z", false)]
        public async Task Delayed_tracks_missing_invalid_or_older_than_90_second_heartbeat(string? heartbeat, bool delayed)
        {
            using var db = NewDb();
            if (heartbeat != null) db.AppSettings.Add(new AppSetting { Key = BetaService.HeartbeatKey, Value = heartbeat });
            await db.SaveChangesAsync();
            var service = Service(db);
            var result = await service.EnrollAsync(new BetaEnrollRequest { Email = "person@gmail.com" });
            Assert.Equal(delayed, result.Delayed);
            Assert.Equal(delayed, (await service.EnrollStatusAsync(" PERSON@gmail.com ")).Delayed);
            Assert.Equal(new BetaEnrollStatus(false, false, false, false), await service.EnrollStatusAsync("unknown@gmail.com"));
            var tester = await db.BetaTesters.SingleAsync();
            await service.SyncFailedAsync(new BetaSyncFailedRequest { Id = tester.Id, Refused = true });
            Assert.Equal(new BetaEnrollStatus(true, false, true, false), await service.EnrollStatusAsync(tester.Email));
            await service.SyncDoneAsync(new[] { tester.Id });
            Assert.Equal(new BetaEnrollStatus(true, true, false, false), await service.EnrollStatusAsync(tester.Email));
            Assert.Null(tester.PlayError);
        }

        [Theory]
        [InlineData(null, true)]
        [InlineData(true, true)]
        [InlineData(false, false)]
        public async Task Failure_supports_legacy_contract_and_current_daemon_refusal_flag(bool? refused, bool rejected)
        {
            using var db = NewDb();
            var service = Service(db);
            await service.EnrollAsync(new BetaEnrollRequest { Email = "person@gmail.com" });
            var tester = await db.BetaTesters.SingleAsync();
            Assert.True(await service.SyncFailedAsync(new BetaSyncFailedRequest { Id = tester.Id, Reason = "timeout", Refused = refused }));
            Assert.Equal(rejected, (await service.EnrollStatusAsync(tester.Email)).Rejected);
            Assert.Equal(rejected ? 0 : 1, (await service.PendingAsync()).Testers.Count);
            Assert.Equal(1, tester.SyncAttempts);
            Assert.NotNull(tester.LastCheckedAt);
            await service.RetrySyncAsync(tester.Id);
            Assert.Null(tester.PlayError);
            Assert.Equal(0, tester.SyncAttempts);
        }

        private sealed class FailHeartbeatSave : SaveChangesInterceptor
        {
            public override ValueTask<InterceptionResult<int>> SavingChangesAsync(DbContextEventData eventData,
                InterceptionResult<int> result, CancellationToken cancellationToken = default)
            {
                if (eventData.Context!.ChangeTracker.Entries<AppSetting>().Any())
                    throw new InvalidOperationException("Simulated heartbeat write failure");
                return ValueTask.FromResult(result);
            }
        }

        [Fact]
        public async Task Heartbeat_write_failure_does_not_fail_or_empty_pending_queue()
        {
            using var db = NewDb(new FailHeartbeatSave());
            db.BetaTesters.Add(new BetaTester { Email = "person@gmail.com" });
            await db.SaveChangesAsync();
            Assert.Single((await Service(db).PendingAsync()).Testers);
            Assert.Empty(db.ChangeTracker.Entries<AppSetting>());
        }
    }
}
