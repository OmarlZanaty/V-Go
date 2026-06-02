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
        public Task SendToDeviceAsync(string deviceToken, PushFireBaseNotificationMessage message, CancellationToken ct = default);
        public Task SendToMultipleDevicesAsync(List<string> deviceTokens, PushFireBaseNotificationMessage message, CancellationToken ct = default);

    }
}
