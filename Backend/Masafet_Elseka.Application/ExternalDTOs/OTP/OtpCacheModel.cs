using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.ExternalDTOs.OTP
{
    public class OtpCacheModel
    {
        public string Otp { get; set; }
        public string Email { get; set; }
        public DateTime ExpirationTime { get; set; }
    }
}
