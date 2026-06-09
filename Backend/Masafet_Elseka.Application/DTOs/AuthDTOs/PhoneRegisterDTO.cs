namespace Masafet_Elseka.Application.DTOs.AuthDTOs
{
    /// <summary>
    /// Completes sign-up for a phone-verified user (no password — phone OTP is
    /// the credential). Email is optional.
    /// </summary>
    public class PhoneRegisterDTO
    {
        public string IdToken { get; set; }
        public string FullName { get; set; }
        public string? Email { get; set; }
        public string? Gender { get; set; }
        public string? FCMToken { get; set; }
        public string? DeviceType { get; set; }
    }
}
