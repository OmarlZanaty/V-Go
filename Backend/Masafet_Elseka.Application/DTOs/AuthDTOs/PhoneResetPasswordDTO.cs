namespace Masafet_Elseka.Application.DTOs.AuthDTOs
{
    /// <summary>
    /// Resets a phone account's password. Phone ownership is proven by a Firebase
    /// Phone-Auth OTP (the only place OTP is still used after the move to
    /// phone + password sign-in).
    /// </summary>
    public class PhoneResetPasswordDTO
    {
        public string IdToken { get; set; }
        public string NewPassword { get; set; }
    }
}
