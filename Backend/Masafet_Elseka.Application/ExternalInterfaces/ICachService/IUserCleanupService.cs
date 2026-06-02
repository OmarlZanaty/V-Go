using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.ExternalInterfaces.ICachService
{
    public interface IUserCleanupService
    {
        Task ScheduleUserCleanupAsync(string userId, string email);
        Task DeleteUserIfNotConfirmedAsync(string userId, string email);
    }

}
