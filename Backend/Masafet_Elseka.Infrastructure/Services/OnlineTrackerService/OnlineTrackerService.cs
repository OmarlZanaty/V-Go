using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Services.OnlineTrackerService
{
    public class OnlineTrackerService
    {
        private readonly ConcurrentDictionary<string, (string Role, DateTime LastActiveUtc)> _online = new();

        public void MarkOnline(string userId, string role)
            => _online[userId] = (role, DateTime.Now.ToEgyptTime());

        public void MarkOffline(string userId)
            => _online.TryRemove(userId, out _);

        public IReadOnlyDictionary<string, (string Role, DateTime LastActiveUtc)> GetOnline()
            => _online;
    }
}
