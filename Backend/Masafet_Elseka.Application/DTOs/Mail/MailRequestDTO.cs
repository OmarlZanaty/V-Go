using Microsoft.AspNetCore.Http;
using System.ComponentModel.DataAnnotations;

namespace Masafet_Elseka.Application.DTOs
{
    public class MailRequestDTO
    {
        public string? Email { get; set; }
        [Required]
        public string? Subject { get; set; }
        [Required]
        public string? Body { get; set; }
        public IList<IFormFile>? Attachments { get; set; }
    }
}
