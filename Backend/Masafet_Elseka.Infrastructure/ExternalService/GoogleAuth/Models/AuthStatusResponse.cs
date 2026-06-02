using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.Models
{
    public class AuthStatusResponse
    {
        public bool Success { get; set; }
        public string Status { get; set; }
        public string Message { get; set; }
        public object User { get; set; }
    }
}
