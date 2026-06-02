using Masafet_Elseka.Application.DTOs.AuthDTOs;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.Models
{
    public class AuthState
    {
        public string State { get; set; }
        public string Code { get; set; }
        public DateTime CreatedAt { get; set; }
        public bool IsUsed { get; set; }
        public string Status { get; set; } 
        public LoginResponseDTO UserData { get; set; }
        public string Token { get; set; }
        public string RefreshToken { get; set; }
    }
}
