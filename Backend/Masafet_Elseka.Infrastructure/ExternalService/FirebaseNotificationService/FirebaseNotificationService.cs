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

        public async Task SendToDeviceAsync(string deviceToken, PushFireBaseNotificationMessage message,CancellationToken ct=default)
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

                string response = await _firebaseMessaging.SendAsync(fbMessage);
                _logger.LogInformation("Successfully sent message to device {DeviceToken}. Response: {Response}", deviceToken, response);
            }
            catch (FirebaseMessagingException ex)
            {
                _logger.LogError(ex, "Firebase error sending to device {DeviceToken}", deviceToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error sending to device", deviceToken);
            }
        }

        public async Task SendToMultipleDevicesAsync(List<string> deviceTokens, PushFireBaseNotificationMessage message, CancellationToken ct = default)
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
        }


    }
}
