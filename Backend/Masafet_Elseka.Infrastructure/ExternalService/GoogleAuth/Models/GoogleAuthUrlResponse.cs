using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.Models
{
    public class GoogleAuthUrlResponse
    {
        public bool Success { get; set; }
        public string AuthUrl { get; set; }
        public string State { get; set; }
        public string RedirectUri { get; set; }
        public string Message { get; set; }
    }
}
