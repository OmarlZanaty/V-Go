using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Masafet_Elseka.Application.DTOs.PushFireBaseNotificationMessage;
using Masafet_Elseka.Application.ExternalInterfaces.IFirebaseNotificationService;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.ExternalService.FirebaseNotificationService
{
    public class FirebaseNotificationService : IFirebaseNotificationService
    {
        private readonly FirebaseMessaging _firebaseMessaging;
        private readonly ILogger<FirebaseNotificationService> _logger;

        public FirebaseNotificationService(ILogger<FirebaseNotificationService> logger)
        {
            _firebaseMessaging = FirebaseMessaging.DefaultInstance;
            _logger = logger;
        }

        /// <summary>
        /// A token FCM will never deliver to again: the app was uninstalled or its
        /// registration expired (Unregistered), or the token belongs to a different
        /// Firebase project (SenderIdMismatch — the client app used to initialise
        /// against the wrong project, and those tokens are still in the table).
        /// </summary>
        private static bool IsDead(FirebaseMessagingException? ex) =>
            ex != null && (ex.MessagingErrorCode == MessagingErrorCode.Unregistered
                        || ex.MessagingErrorCode == MessagingErrorCode.SenderIdMismatch
                        || ex.MessagingErrorCode == MessagingErrorCode.InvalidArgument);

        public async Task<IReadOnlyList<string>> SendToDeviceAsync(string deviceToken, PushFireBaseNotificationMessage message,CancellationToken ct=default)
        {
            try
            {
                var fbMessage = new Message
                {
                    Token = deviceToken,
                    Notification = new FirebaseAdmin.Messaging.Notification
                    {
                        Title = message.Title,
                        Body = message.Body
                    },
                    Data = message.Data ?? new Dictionary<string, string>()
                };

                string response = await _firebaseMessaging.SendAsync(fbMessage, ct);
                _logger.LogInformation("Successfully sent message to device {DeviceToken}. Response: {Response}", deviceToken, response);
            }
            catch (FirebaseMessagingException ex)
            {
                _logger.LogError(ex, "Firebase error {Code} sending to device {DeviceToken}", ex.MessagingErrorCode, deviceToken);
                if (IsDead(ex)) return new[] { deviceToken };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error sending to device {DeviceToken}", deviceToken);
            }
            return Array.Empty<string>();
        }

        public async Task<IReadOnlyList<string>> SendToMultipleDevicesAsync(List<string> deviceTokens, PushFireBaseNotificationMessage message, CancellationToken ct = default)
        {
            var multicastMessage = new MulticastMessage
            {
                Tokens = deviceTokens,
                Notification = new FirebaseAdmin.Messaging.Notification
                {
                    Title = message.Title,
                    Body = message.Body
                },
                Data = message.Data ?? new Dictionary<string, string>()
            };

            var response = await _firebaseMessaging.SendEachForMulticastAsync(multicastMessage, ct);

            _logger.LogInformation("Sent multicast to {Count} devices. Success: {SuccessCount}, Failure: {FailureCount}",
                deviceTokens.Count, response.SuccessCount, response.FailureCount);

            var dead = new List<string>();
            for (var i = 0; i < response.Responses.Count && i < deviceTokens.Count; i++)
            {
                var r = response.Responses[i];
                if (r.IsSuccess) continue;
                _logger.LogWarning("Push to device {DeviceToken} failed: {Code} {Message}",
                    deviceTokens[i], r.Exception?.MessagingErrorCode, r.Exception?.Message);
                if (IsDead(r.Exception)) dead.Add(deviceTokens[i]);
            }
            return dead;
        }


    }
}
