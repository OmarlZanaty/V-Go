using System.Collections.Concurrent;

namespace Masafet_Elseka.Application.Helpers
{
    // Short-lived per-user "is blocked" answers so the blocked-user gate doesn't hit
    // the database on every request. Block/unblock evicts the user right away.
    public static class BlockedUserCache
    {
        private static readonly TimeSpan Ttl = TimeSpan.FromSeconds(30);
        private static readonly ConcurrentDictionary<string, (bool Blocked, DateTime At)> Entries = new();

        public static bool TryGet(string userId, out bool blocked)
        {
            blocked = false;
            if (!Entries.TryGetValue(userId, out var entry) || DateTime.UtcNow - entry.At > Ttl)
                return false;
            blocked = entry.Blocked;
            return true;
        }

        public static void Set(string userId, bool blocked) => Entries[userId] = (blocked, DateTime.UtcNow);

        public static void Evict(string userId) => Entries.TryRemove(userId, out _);
    }
}
