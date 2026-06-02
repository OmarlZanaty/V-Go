using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Payment
{
    public class PaymentRequestDTO
    {
        public string UserId { get; set; }
        public string TripId { get; set; }
        public decimal Price { get; set; }
        public string Currency { get; set; } = "EGP";
    }
}
