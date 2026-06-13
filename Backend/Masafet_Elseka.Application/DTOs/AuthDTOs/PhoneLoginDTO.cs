namespace Masafet_Elseka.Application.DTOs.AuthDTOs
{
    /// <summary>
    /// Phone + password sign-in (OTP removed). The backend looks the user up by
    /// phone number and verifies the password via ASP.NET Identity.
    /// </summary>
    public class PhoneLoginDTO
    {
        public string Phone { get; set; }
        public string Password { get; set; }
        public string? FCMToken { get; set; }
        public string? DeviceType { get; set; }
    }
}
