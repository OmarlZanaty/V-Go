using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.AuthDTOs
{
    public class ResetPasswordDTO
    {

        [Required,PasswordPropertyText, MinLength(6)]
        public string NewPassword { get; set; }
        [Required, EmailAddress]
        public string Email { get; set; }
    }
}
