using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.Models
{
    public class GoogleCallbackRequest
    {
        public string Code { get; set; }
        public string State { get; set; }
    }
}
