using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Infrastructure.Data;
using Masafet_Elseka.Infrastructure.Services.NotificationService;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Masafet_Elseka.Tests
{
    public class BroadcastSelectionTests
    {
        private static async Task<Context> Seed(int clients, int drivers = 0)
        {
            var db = BetaServiceTests.NewDb();
            db.Roles.Add(new IdentityRole { Id = "rc", Name = "Client", NormalizedName = "CLIENT" });
            db.Roles.Add(new IdentityRole { Id = "rd", Name = "Driver", NormalizedName = "DRIVER" });
            void Add(string id, string role, bool blocked = false, bool deleted = false)
            {
                db.Users.Add(new ApplicationUser { Id = id, UserName = id, FullName = id, Gender = "Male", IsBlocked = blocked, IsDeleted = deleted });
                db.UserRoles.Add(new IdentityUserRole<string> { UserId = id, RoleId = role });
            }
            for (var i = 0; i < clients; i++) Add("c" + i, "rc");
            for (var i = 0; i < drivers; i++) Add("d" + i, "rd");
            Add("blocked", "rc", blocked: true);
            Add("deleted", "rc", deleted: true);
            await db.SaveChangesAsync();
            return db;
        }

        private static async Task Send(Context db, IEnumerable<string> ids)
        {
            db.Notifications.AddRange(ids.Select(id => new Notification { UserId = id, Title = "t", Body = "b", IsBroadcast = true }));
            await db.SaveChangesAsync();
        }

        [Fact]
        public async Task Candidates_exclude_blocked_deleted_and_other_roles()
        {
            using var db = await Seed(5, 3);
            Assert.Equal(5, await BroadcastSelection.CandidateIds(db, BroadcastSelection.RolesFor("Client"), false).CountAsync());
            Assert.Equal(3, await BroadcastSelection.CandidateIds(db, BroadcastSelection.RolesFor("Driver"), false).CountAsync());
            Assert.Equal(8, await BroadcastSelection.CandidateIds(db, BroadcastSelection.RolesFor(null), false).CountAsync());
        }

        [Fact]
        public void Pick_respects_limit_and_returns_distinct_ids()
        {
            var ids = Enumerable.Range(0, 50).Select(i => "u" + i).ToList();
            var picked = BroadcastSelection.Pick(ids, 15);
            Assert.Equal(15, picked.Count);
            Assert.Equal(15, picked.Distinct().Count());
            Assert.All(picked, p => Assert.Contains(p, ids));
        }

        [Fact]
        public void Pick_with_fewer_candidates_than_limit_returns_all()
        {
            var picked = BroadcastSelection.Pick(new[] { "a", "b", "c" }, 15);
            Assert.Equal(new[] { "a", "b", "c" }, picked.OrderBy(x => x));
            Assert.Empty(BroadcastSelection.Pick(Array.Empty<string>(), 5));
        }

        [Fact]
        public void Pick_is_actually_random()
        {
            var ids = Enumerable.Range(0, 30).Select(i => "u" + i).ToList();
            var seen = new HashSet<string>();
            for (var i = 0; i < 40; i++) foreach (var p in BroadcastSelection.Pick(ids, 3)) seen.Add(p);
            Assert.True(seen.Count > 15);
        }

        [Fact]
        public async Task OnlyNew_never_repeats_across_two_sends()
        {
            using var db = await Seed(20);
            var roles = BroadcastSelection.RolesFor("Client");
            var first = BroadcastSelection.Pick(await BroadcastSelection.CandidateIds(db, roles, true).ToListAsync(), 15);
            await Send(db, first);
            var second = BroadcastSelection.Pick(await BroadcastSelection.CandidateIds(db, roles, true).ToListAsync(), 15);
            Assert.Equal(5, second.Count);
            Assert.Empty(first.Intersect(second));
            await Send(db, second);
            Assert.Equal(0, await BroadcastSelection.CandidateIds(db, roles, true).CountAsync());
            Assert.Equal(20, await BroadcastSelection.CandidateIds(db, roles, false).CountAsync());
        }

        [Fact]
        public async Task ReachableOnly_keeps_only_users_with_an_active_device()
        {
            using var db = await Seed(4);
            db.Set<UserDevice>().AddRange(
                new UserDevice { UserId = "c0", DeviceToken = "t0", IsActive = true },
                new UserDevice { UserId = "c1", DeviceToken = "t1", IsActive = false },
                new UserDevice { UserId = "c2", DeviceToken = "t2", IsActive = true, IsDeletd = true },
                new UserDevice { UserId = "blocked", DeviceToken = "tb", IsActive = true });
            await db.SaveChangesAsync();
            var roles = BroadcastSelection.RolesFor("Client");
            Assert.Equal(new[] { "c0" }, await BroadcastSelection.CandidateIds(db, roles, true, reachableOnly: true).ToListAsync());
            await Send(db, new[] { "c0" });
            Assert.Equal(0, await BroadcastSelection.CandidateIds(db, roles, true, reachableOnly: true).CountAsync());
        }

        [Fact]
        public async Task OnlyNew_false_ignores_previous_broadcasts_and_plain_notifications_do_not_count()
        {
            using var db = await Seed(4);
            db.Notifications.Add(new Notification { UserId = "c0", Title = "t", Body = "b", IsBroadcast = false });
            await Send(db, new[] { "c1" });
            var roles = BroadcastSelection.RolesFor("Client");
            Assert.Equal(3, await BroadcastSelection.CandidateIds(db, roles, true).CountAsync());
            Assert.Equal(4, await BroadcastSelection.CandidateIds(db, roles, false).CountAsync());
        }
    }
}
