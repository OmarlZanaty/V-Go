using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.Models
{
    public class MobileAuthRequest
    {
        public string Code { get; set; }
        public string DeviceId { get; set; }
        public string Platform { get; set; } = "flutter";
    }
}
