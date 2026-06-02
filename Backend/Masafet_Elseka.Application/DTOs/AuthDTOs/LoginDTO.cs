using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.AuthDTOs
{
    public class LoginDTO
    {
        [Required,EmailAddress]
        public string Email { get; set; }

        [Required,PasswordPropertyText]
        public string Password { get; set; }
        public string? FCMToken { get; set; }
        public string? DeviceType { get; set; }

    }
}
