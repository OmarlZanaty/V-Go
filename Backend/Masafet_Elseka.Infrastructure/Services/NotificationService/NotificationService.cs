using Masafet_Elseka.Application.Common.Pagination;
using Masafet_Elseka.Application.DTOs.Notification;
using Masafet_Elseka.Application.DTOs.PushFireBaseNotificationMessage;
using Masafet_Elseka.Application.ExternalInterfaces.IFirebaseNotificationService;
using Masafet_Elseka.Application.Interfaces.INotificationService;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Infrastructure.Data;
using Masafet_Elseka.Infrastructure.ExtensionMethods;
using Masafet_Elseka.Infrastructure.UOW;
using Microsoft.AspNetCore.Identity;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Services.NotificationService
{
    public class NotificationService : INotificationService
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly IFirebaseNotificationService _firebaseNotification;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly Context _context;

        public NotificationService(IUnitOfWork unitOfWork, IFirebaseNotificationService firebaseNotification, UserManager<ApplicationUser> userManager, Context context)
        {
            _unitOfWork = unitOfWork;
            _firebaseNotification = firebaseNotification;
            _userManager = userManager;
            _context = context;
        }

        public async Task RegisterDeviceAsync(string userId, string deviceToken, string deviceType, string? deviceId = null, CancellationToken ct = default)
        {
            if (string.IsNullOrWhiteSpace(deviceToken)) throw new ArgumentException("deviceToken is required");

            var existing = await _unitOfWork.UserDevices.GetByExpressionAsync(d => d.DeviceToken == deviceToken, ct);
            if (existing != null)
            {
                existing.UserId = userId;
                existing.DeviceType = deviceType;
                existing.IsActive = true;
                existing.LastActive = DateTime.Now.ToEgyptTime();
            }   
            else
            {
                var device = new UserDevice
                {
                    UserId = userId,
                    DeviceToken = deviceToken,
                    DeviceType = deviceType,
                    IsActive = true,
                    LastActive = DateTime.Now.ToEgyptTime(),
                    CreatedAt = DateTime.Now.ToEgyptTime()
                };
               await _unitOfWork.UserDevices.AddAsync(device,ct);
            }
            await _unitOfWork.SaveAsync(ct);
        }
        public async Task UnregisterDeviceAsync(string deviceToken, CancellationToken ct = default)
        {
            if (string.IsNullOrWhiteSpace(deviceToken))
                throw new ArgumentException("deviceToken is required");

            var device = await _unitOfWork.UserDevices
                  .GetByExpressionAsync(d => d.DeviceToken == deviceToken, ct);

            if (device == null)
                return; 

            device.IsActive = false;
            device.IsDeletd=true;
            device.LastActive = DateTime.Now.ToEgyptTime();

            await _unitOfWork.SaveAsync(ct);
        }

        public async Task SendNotificationToUserAsync(string userId,string title,string body, Dictionary<string, string>? data = null,CancellationToken ct = default)
        {
            if (string.IsNullOrWhiteSpace(userId))
                throw new ArgumentException("userId is required");

            var devices = await _unitOfWork.UserDevices
                .GetAllByExpressionAsync(d => d.UserId == userId && d.IsActive && !d.IsDeletd, ct);

            if (devices == null || !devices.Any())
                return; 

            var tokens = devices.Select(d => d.DeviceToken).ToList();

            var pushNotification = new PushFireBaseNotificationMessage
            {

                Title = title,
                Body = body,
                Data = data
            };
            if (tokens.Count == 1)
            {               
                await _firebaseNotification.SendToDeviceAsync(tokens.First(), pushNotification,ct);
            }
            else
            {
                await _firebaseNotification.SendToMultipleDevicesAsync(tokens!, pushNotification, ct);
            }
        }

        public async Task SendNotificationToUserWithSavingAsync(string userId, string title, string body, Dictionary<string, string>? data = null, CancellationToken ct = default)
        {
            var notification = new Notification
            {
                UserId = userId,
                Title = title,
                Body = body,
                CreatedAt = DateTime.Now.ToEgyptTime(),
                IsRead = false
            };

            await _unitOfWork.Notifications.AddAsync(notification, ct);
            await _unitOfWork.SaveAsync(ct);

            await SendNotificationToUserAsync(userId, title, body, data, ct);
        }


        public async Task<Response<object>> DeleteNotificationsAsync(string userId, List<int> notificationIds, CancellationToken ct = default)
        {
            if (string.IsNullOrWhiteSpace(userId))
                return Response<object>.Failure("User Id Required! ",400);

            if (notificationIds == null || !notificationIds.Any())
                return Response<object>.Failure("notificationIds Should be not Null ", 400);

            var notifications = await _unitOfWork.Notifications
                  .GetAllByExpressionAsync(n => n.UserId == userId && notificationIds.Contains(n.Id), ct);

            if (notifications == null || !notifications.Any())
                return Response<object>.Failure("notifications Not Found ", 404);
            var deletedNotifications= new List<Notification>();

            foreach (var n in notifications)
            {
                deletedNotifications.Add(n);
            }
            await _unitOfWork.Notifications.DeleteRangeAsync(deletedNotifications);
            var affectedRows = await _unitOfWork.SaveAsync(ct);
            return Response<object>.Success(affectedRows,"تم حذف الاشعار/ الاشعارات بنجاح ",200);
        }

        public async Task<Response<object>> MarkAsReadAsync(string userId, int notificationId, CancellationToken ct = default)
        {
            if (string.IsNullOrWhiteSpace(userId))
                return Response<object>.Failure("UserId Required!", 400);

            var notification = await _unitOfWork.Notifications
                .GetByExpressionAsync(n => n.UserId == userId && n.Id == notificationId, ct);

            if (notification == null)
                return Response<object>.Failure("notifications Not Found ", 404);

            notification.IsRead = true;
            var row= await _unitOfWork.SaveAsync(ct);

            return Response<object>.Success(row,"تمت قراءة الاشعار بنجاح",200);
        }

        public async Task<Response<object>> MarkAllAsReadAsync(string userId, CancellationToken ct = default)
        {
            if (string.IsNullOrWhiteSpace(userId))
                return Response<object>.Failure("UserId Required!", 400);

            var notifications = await _unitOfWork.Notifications
                .GetAllByExpressionAsync(n => n.UserId == userId && !n.IsRead, ct);

            if (notifications == null || !notifications.Any())
                return Response<object>.Failure("notifications Not Found ", 404);

            foreach (var n in notifications)
            {
                n.IsRead = true;
            }

           var affectedRows= await _unitOfWork.SaveAsync(ct);
            return Response<object>.Success(affectedRows, "تمت قراءة الاشعار/ الاسعارات بنجاح", 200);
        }

        public async Task<Response<PaginationPagedResponse<NotificationDTO>>> GetAllForUser(string userId, PaginationRequest pagination, CancellationToken ct = default)
        {
            var user = await _userManager.FindByIdAsync(userId);
            if (user == null)
                return Response<PaginationPagedResponse<NotificationDTO>>.Failure("المستخدم غير موجود", 404);

            try
            {
                var query = _context.Notifications
                    .Where(n => n.UserId == userId)
                    .OrderByDescending(n => n.CreatedAt)
                    .Select(n => new NotificationDTO
                    {
                        Id = n.Id,
                        Title = n.Title,
                        Body = n.Body ?? "",
                        IsRead = n.IsRead,
                        CreatedAt = n.CreatedAt
                    })
                    .AsQueryable();

                var pagedResult = await query.ToPagedResponseAsync(
                    pagination.PageNumber,
                    pagination.PageSize,
                    ct);

                if (pagedResult.Data.Count == 0) {
                    pagedResult.Data = new List<NotificationDTO>();
                    return Response<PaginationPagedResponse<NotificationDTO>>.Success(pagedResult, "لا توجد اشعارات", 200);
                }
                    

                return Response<PaginationPagedResponse<NotificationDTO>>.Success(pagedResult, "تم جلب جميع الاشعارات", 200);
            }
            catch (Exception ex)
            {
                return Response<PaginationPagedResponse<NotificationDTO>>.Failure($"حدث خطأ غير متوقع: {ex.Message}", 500);
            }
        }
    }
}
