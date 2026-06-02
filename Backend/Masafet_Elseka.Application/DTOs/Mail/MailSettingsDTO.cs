using System.ComponentModel.DataAnnotations;

namespace Masafet_Elseka.Application.DTOs
{
    public class MailSettingsDTO
    {
        public string? Email { get; set; }

        [Required(ErrorMessage = "Display name is required.")]
        [MaxLength(50, ErrorMessage = "Display name cannot exceed 50 characters.")]
        public string? DisplayName { get; set; }

        [Required(ErrorMessage = "Password is required.")]
        [DataType(DataType.Password)]
        public string? Password { get; set; }

        [Required(ErrorMessage = "Host is required.")]
        public string? Host { get; set; }

        [Required(ErrorMessage = "Port is required.")]
        public int Port { get; set; }
    }
}
