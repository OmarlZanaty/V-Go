using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.Interfaces.IDispatcherService
{
    public interface IDispatcherService
    {
        Task<string> GetAvailableDispatcherId();
        Task<bool> UpdateDispatcherAvailability(string id, bool isAvailable);
    }
}
