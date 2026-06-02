using Masafet_Elseka.Domain.Enums;
using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.User
{
    public class UpdateAllDTO
    {
        public string? Name { get; set; }
        public string? PhoneNumber { get; set; }
        public string? NationalId { get; set; }
        public string? Gender { get; set; }
        public IFormFile? ProfilePicture { get; set; }
        public string? ProfilePicturePath { get; set; }
        public string? License { get; set; }
        public ScooterType? ScooterType { get; set; }
        public string? ScooterLicense { get; set; }
    }
}
