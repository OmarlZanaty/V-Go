using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Client
{
    public class ClientTripDataDTO
    {
        public string ClientId { get; set; }
        public string FullName { get; set; }
        public string PhoneNumber { get; set; }
        public string? ProfileImageUrl { get; set; }
        public double Rating { get; set; }
    }
}
