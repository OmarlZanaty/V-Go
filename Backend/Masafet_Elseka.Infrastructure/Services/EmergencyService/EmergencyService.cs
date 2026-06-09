using Masafet_Elseka.Application.DTOs.Driver;
using Masafet_Elseka.Application.Interfaces.IEmergencyService;
using Masafet_Elseka.Application.Interfaces.INotificationService;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Infrastructure.Data;
using Masafet_Elseka.Infrastructure.Services.OnlineTrackerService;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Services.EmergencyService
{
    public class EmergencyService: IEmergencyService
    {
        private readonly Context _context;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly INotificationService _notificationService;
        private readonly OnlineTrackerService.OnlineTrackerService _onlineTrackerService;

        public EmergencyService(Context context, INotificationService notificationService, UserManager<ApplicationUser> userManager, OnlineTrackerService.OnlineTrackerService onlineTrackerService)
        {
            _context = context;
            _notificationService = notificationService;
            _userManager = userManager;
            _onlineTrackerService = onlineTrackerService;
        }

        public async Task<Response<DriverAlertDataDTO>> SendAlert(AlertDTO model)
        {
            try
            {
                var driver = await _context.Users.FindAsync(model.DriverId);
                if (driver == null)
                {
                    return Response<DriverAlertDataDTO>.Failure("السائق غير موجود", 404);
                }

                var adminsIds= _onlineTrackerService.GetOnline()
                    .Where(o=>o.Value.Role=="Admin")
                    .Select(o=>o.Key).ToList();

                if (adminsIds.Any())
                {
                    foreach (var adminId in adminsIds)
                    {
                        var admin = await _context.Users.FindAsync(adminId);
                        if (admin != null)
                        {
                            await _notificationService.SendNotificationToUserAsync(
                                         adminId,
                                         "تنبيه طارئ من سائق",
                                         $"السائق {driver.FullName}\n أرسل استغاثة عاجلة، يرجى التوجه لموقعه أو الاتصال به.",
                                         new Dictionary<string, string> { { "DriverId", driver.Id.ToString() } }
                                     );      
                        }
                    }
                }

                return Response<DriverAlertDataDTO>.Success(new DriverAlertDataDTO
                {
                    Id = driver.Id,
                    Name = driver.FullName,
                    PhoneNumber = driver.PhoneNumber,
                    ProfilePicture= driver.ProfilePicture,
                    Latitude = model.Latitude,
                    Longitude = model.Longitude,
                    AlertTime= DateTime.Now.ToEgyptTime()
                }, "تم إرسال التنبيه الطارئ بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<DriverAlertDataDTO>.Failure($"حدث خطأ أثناء إرسال التنبيه الطارئ", 500);
            }
        }
    }
}
