using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.ExternalInterfaces.ICachService
{
    public interface ICacheService
    {
        T? GetData<T>(string key);
        void SetData<T>(string key, T value, TimeSpan? expiration = null);
        public Task SetKeyToList(string keysList, string key);
        public Task RemoveDataAsync(string key);
        public Task RemoveKeyFromList(string keysList, string key);
    }
}
