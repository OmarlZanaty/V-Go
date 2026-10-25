namespace Masafet_Elseka.Application.DTOs.AuthDTOs
{
    /// <summary>
    /// Resets a phone account's password using a Collector OTP reset token or a
    /// legacy Firebase Phone-Auth ID token.
    /// </summary>
    public class PhoneResetPasswordDTO
    {
        public string? IdToken { get; set; }
        public string? ResetToken { get; set; }
        public string NewPassword { get; set; }
    }
}
