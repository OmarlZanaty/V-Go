namespace Masafet_Elseka.Application.DTOs.AuthDTOs
{
    /// <summary>
    /// Driver (captain) sign-up for a phone-verified user — no password. Includes
    /// the driver docs + scooter info. ScooterType: 0 = Gasoline, 1 = Electric.
    /// </summary>
    public class PhoneRegisterDriverDTO
    {
        public string IdToken { get; set; }
        public string FullName { get; set; }
        public string? Email { get; set; }
        public string? Gender { get; set; }
        public string? NationalId { get; set; }
        public string? DriverLicense { get; set; }
        public int ScooterType { get; set; }
        public string? ScooterLicense { get; set; }
        public string? FCMToken { get; set; }
        public string? DeviceType { get; set; }
    }
}
