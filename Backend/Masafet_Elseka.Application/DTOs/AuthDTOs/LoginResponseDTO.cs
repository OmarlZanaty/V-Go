using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.AuthDTOs
{
    public class LoginResponseDTO
    {
        public string UserId { get; set; }
        public string Name { get; set; }
        public string Gender { get; set; }
        public bool IsAuthenticated { get; set; }
        public string? ProfilePicture { get; set; }= string.Empty;
        public string? NationalId { get; set; } = string.Empty;
        public string? License { get; set; } = string.Empty;
        public string Token { get; set; }
        public string RefreshToken { get; set; }
        public DateTime RefreshTokenExpiration { get; set; }
        public List<string> Roles { get; set; }
    }
}
