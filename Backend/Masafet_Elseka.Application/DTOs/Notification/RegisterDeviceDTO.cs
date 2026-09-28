namespace Masafet_Elseka.Application.DTOs.Notification
{
    public class RegisterDeviceDTO
    {
        public string FCMToken { get; set; } = string.Empty;
        public string? DeviceType { get; set; }
    }
}
