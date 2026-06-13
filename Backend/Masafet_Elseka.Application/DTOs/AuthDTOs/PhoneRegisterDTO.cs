namespace Masafet_Elseka.Application.DTOs.AuthDTOs
{
    /// <summary>
    /// Phone + password sign-up for a rider (OTP removed). The phone becomes the
    /// username and the password is the account credential. Email is optional.
    /// </summary>
    public class PhoneRegisterDTO
    {
        public string Phone { get; set; }
        public string Password { get; set; }
        public string FullName { get; set; }
        public string? Email { get; set; }
        public string? Gender { get; set; }
        public string? FCMToken { get; set; }
        public string? DeviceType { get; set; }
    }
}
