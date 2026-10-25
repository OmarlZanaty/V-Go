namespace Masafet_Elseka.Application.DTOs.AuthDTOs
{
    public class PhoneOtpRequestDTO
    {
        public string? Phone { get; set; }
    }

    public class PhoneOtpVerifyDTO : PhoneOtpRequestDTO
    {
        public string? Code { get; set; }
    }
}
