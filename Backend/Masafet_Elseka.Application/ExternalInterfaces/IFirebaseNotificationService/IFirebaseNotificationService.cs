using Masafet_Elseka.Application.DTOs.PushFireBaseNotificationMessage;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.ExternalInterfaces.IFirebaseNotificationService
{
    public interface IFirebaseNotificationService
    {
        /// <summary>
        /// Both return the tokens FCM reported as permanently dead (unregistered,
        /// or issued by another Firebase project) so the caller can deactivate
        /// them. A transient failure is logged and NOT returned.
        /// </summary>
        public Task<IReadOnlyList<string>> SendToDeviceAsync(string deviceToken, PushFireBaseNotificationMessage message, CancellationToken ct = default);
        public Task<IReadOnlyList<string>> SendToMultipleDevicesAsync(List<string> deviceTokens, PushFireBaseNotificationMessage message, CancellationToken ct = default);

    }
}
