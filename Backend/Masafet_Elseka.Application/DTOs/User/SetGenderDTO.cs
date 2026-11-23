namespace Masafet_Elseka.Application.DTOs.User
{
    public class SetGenderDTO
    {
        // "Male" | "Female" (Arabic ذكر / أنثى and lowercase are accepted and normalized).
        public string? Gender { get; set; }
    }
}
