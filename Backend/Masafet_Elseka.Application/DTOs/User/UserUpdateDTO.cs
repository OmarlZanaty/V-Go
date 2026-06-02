using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.User
{
    public class UserUpdateDTO
    {
        public string? Name { get; set; }
        public string? PhoneNumber { get; set; }
        public string? Gender { get; set; }
        public IFormFile? ProfilePicture { get; set; }
    }
}
