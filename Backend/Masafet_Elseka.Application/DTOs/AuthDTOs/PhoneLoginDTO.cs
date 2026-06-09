namespace Masafet_Elseka.Application.DTOs.AuthDTOs
{
    /// <summary>
    /// Sent by the apps after the user verifies their phone OTP with Firebase
    /// Phone Auth. The backend verifies the Firebase ID token, then logs the
    /// user in (or signals a new user that must complete sign-up).
    /// </summary>
    public class PhoneLoginDTO
    {
        public string IdToken { get; set; }
        public string? FCMToken { get; set; }
        public string? DeviceType { get; set; }
    }
}
