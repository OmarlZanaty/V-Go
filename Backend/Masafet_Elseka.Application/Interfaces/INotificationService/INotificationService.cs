using Masafet_Elseka.Application.Common.Pagination;
using Masafet_Elseka.Application.DTOs.Notification;
using Masafet_Elseka.Application.Response;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.Interfaces.INotificationService
{
    public interface INotificationService
    {
       Task RegisterDeviceAsync(string userId, string deviceToken, string deviceType, string? deviceId = null, CancellationToken ct = default);
       Task UnregisterDeviceAsync(string deviceToken, CancellationToken ct = default);
       Task SendNotificationToUserAsync(string userId, string title, string body, Dictionary<string, string>? data = null, CancellationToken ct = default);
       Task SendNotificationToUserWithSavingAsync(string userId, string title, string body, Dictionary<string, string>? data = null, CancellationToken ct = default);
       Task<Response<object>> DeleteNotificationsAsync(string userId, List<int> notificationIds, CancellationToken ct = default);
       Task<Response<object>> MarkAsReadAsync(string userId, int notificationId, CancellationToken ct = default);
       Task<Response<object>> MarkAllAsReadAsync(string userId, CancellationToken ct = default);
        Task<Response<PaginationPagedResponse<NotificationDTO>>> GetAllForUser(string userId, PaginationRequest pagination, CancellationToken ct = default);
    }
}
