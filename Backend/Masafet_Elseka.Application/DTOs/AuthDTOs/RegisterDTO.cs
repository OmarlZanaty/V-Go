using Masafet_Elseka.Domain.Enums;
using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs
{
    public class RegisterDTO
    {
        public string FullName { get; set; }
        public string Email { get; set; }
        public string Phone { get; set; }
        public string? Gender { get; set; }
        public string Role { get; set; }
        public string? NationalId { get; set; }
        public string? DriverLicense { get; set; }
        public string? ScoterLicense { get; set; }
        public ScooterType? ScoterType { get; set; }
        public IFormFile? Photo { get; set; }

        public string Password { get; set; }
        public string ConfirmPassword { get; set; }

        public string? FCMToken { get; set; }
        public string? DeviceType { get; set; }

    }
}
