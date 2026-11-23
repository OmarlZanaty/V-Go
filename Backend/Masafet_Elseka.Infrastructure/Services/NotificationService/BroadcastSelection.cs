using System.Security.Cryptography;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace Masafet_Elseka.Infrastructure.Services.NotificationService
{
    /// <summary>Who a limited admin broadcast may reach, and the random pick among them.</summary>
    public static class BroadcastSelection
    {
        public static string[] RolesFor(string? role)
            => role is "Client" or "Driver" ? new[] { role } : new[] { "Client", "Driver" };

        /// <summary>Active users in the roles; with onlyNew, minus anyone who already got a broadcast;
        /// with reachableOnly, only users with an active push device (a limited send must spend its
        /// quota on phones that actually get the push, not on accounts with no token).</summary>
        public static IQueryable<string> CandidateIds(Context db, string[] roles, bool onlyNew, bool reachableOnly = false)
        {
            var users = db.Users.Where(u => !u.IsDeleted && !u.IsBlocked
                && (from ur in db.UserRoles
                    join r in db.Roles on ur.RoleId equals r.Id
                    where ur.UserId == u.Id && roles.Contains(r.Name!)
                    select 1).Any());
            if (onlyNew)
                users = users.Where(u => !db.Notifications.Any(n => n.IsBroadcast && n.UserId == u.Id));
            if (reachableOnly)
                users = users.Where(u => db.Set<UserDevice>().Any(d => d.UserId == u.Id && d.IsActive && !d.IsDeletd && d.DeviceToken != null && d.DeviceToken != ""));
            return users.Select(u => u.Id);
        }

        /// <summary>Uniform random sample of up to <paramref name="limit"/> ids (partial Fisher-Yates, crypto RNG).</summary>
        public static List<string> Pick(IReadOnlyList<string> candidates, int limit, Func<int, int>? nextInt = null)
        {
            nextInt ??= max => RandomNumberGenerator.GetInt32(max);
            var pool = candidates.Distinct().ToList();
            var take = Math.Min(limit, pool.Count);
            for (var i = 0; i < take; i++)
            {
                var j = i + nextInt(pool.Count - i);
                (pool[i], pool[j]) = (pool[j], pool[i]);
            }
            return pool.GetRange(0, take);
        }
    }
}
