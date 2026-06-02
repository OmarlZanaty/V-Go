using Masafet_Elseka.Application.ExternalInterfaces.ICachService;
using Microsoft.Extensions.Caching.Distributed;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.ExternalService.CachService
{
    public class CacheService : ICacheService
    {
        private readonly IDistributedCache _cache;

        public CacheService(IDistributedCache cache)
        {
            _cache = cache;
        }
        public T? GetData<T>(string key)
        {
            var data = _cache?.GetString(key);

            if (data == null)
            {
                return default(T);
            }

            return JsonSerializer.Deserialize<T>(data);
        }

        public void SetData<T>(string key, T value, TimeSpan? expiration = null)
        {
            var options = new DistributedCacheEntryOptions();

            if (expiration.HasValue)
            {
                options.AbsoluteExpirationRelativeToNow = expiration.Value;
            }
            else
            {
                options.AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(5);
            }

            _cache?.SetString(key, JsonSerializer.Serialize(value), options);
        }

        public async Task SetKeyToList(string keysList, string key)
        {
            var existingkeys = await _cache.GetStringAsync(keysList);
            var keys = string.IsNullOrEmpty(existingkeys)
                ? new HashSet<string>()
                : JsonSerializer.Deserialize<HashSet<string>>(existingkeys);

            keys!.Add(key);
            await _cache.SetStringAsync(keysList, JsonSerializer.Serialize(keys));
        }

        public async Task RemoveDataAsync(string key)
        {
            await _cache.RemoveAsync(key);
        }

        public async Task RemoveKeyFromList(string keysList, string key)
        {
            var existingkeys = await _cache.GetStringAsync(keysList);
            if (string.IsNullOrEmpty(existingkeys))
            {
                return;
            }
            var keys = JsonSerializer.Deserialize<HashSet<string>>(existingkeys);
            if (keys != null && keys.Remove(key))
            {
                await _cache.SetStringAsync(keysList, JsonSerializer.Serialize(keys));
            }
        }
    }
}
