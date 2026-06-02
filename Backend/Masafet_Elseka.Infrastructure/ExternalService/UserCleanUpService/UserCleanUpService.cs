using Hangfire;
using Masafet_Elseka.Application.ExternalDTOs.OTP;
using Masafet_Elseka.Application.ExternalInterfaces.ICachService;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Infrastructure.Data;
using Microsoft.AspNetCore.Identity;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.ExternalService.UserCleanUpService
{
    public class UserCleanupService : IUserCleanupService
    {
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly ICacheService _cacheService;

        public UserCleanupService(UserManager<ApplicationUser> userManager, ICacheService cacheService)
        {
            _userManager = userManager;
            _cacheService = cacheService;
        }

        public async Task ScheduleUserCleanupAsync(string userId, string email)
        {
            BackgroundJob.Schedule<IUserCleanupService>(
                service => service.DeleteUserIfNotConfirmedAsync(userId, email),
                TimeSpan.FromMinutes(11)
            );
        }

        public async Task DeleteUserIfNotConfirmedAsync(string userId, string email)
        {
            var user = await _userManager.FindByIdAsync(userId);
            if (user == null || user.EmailConfirmed)
                return;

            var otp = _cacheService.GetData<OtpCacheModel>($"OTP_Register_{email}");
            if (otp != null)
                return;

            await _userManager.DeleteAsync(user);
        }
    }


}
