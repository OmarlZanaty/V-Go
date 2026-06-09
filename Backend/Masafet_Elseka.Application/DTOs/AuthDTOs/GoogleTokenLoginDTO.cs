namespace Masafet_Elseka.Application.DTOs.AuthDTOs
{
    /// Rider: sign in with Google ID token (from google_sign_in Flutter package).
    /// For a brand-new account, the first call (no FullName/Phone) returns
    /// IsNewUser=true; the app then collects the required profile (full name +
    /// phone, photo optional) and calls again with those fields to create it.
    public class GoogleTokenLoginDTO
    {
        public string IdToken { get; set; } = string.Empty;
        // Required to create a new account (collected on the complete-profile screen)
        public string? FullName { get; set; }
        public string? Phone { get; set; }
        public string? Gender { get; set; }
        public string? ProfilePicture { get; set; } // optional; falls back to the Google photo
        public string? FCMToken { get; set; }
        public string? DeviceType { get; set; }
    }

    /// Captain: sign in with Google ID token — returns IsNewUser=true if not yet a driver.
    public class GoogleTokenDriverDTO
    {
        public string IdToken { get; set; } = string.Empty;
        // Optional — only sent on second call after user fills signup form
        public string? FullName { get; set; }
        public string? Gender { get; set; }
        public string? NationalId { get; set; }
        public string? DriverLicense { get; set; }
        public int ScooterType { get; set; }
        public string? ScooterLicense { get; set; }
        public string? FCMToken { get; set; }
        public string? DeviceType { get; set; }
    }
}
