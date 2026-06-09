using Masafet_Elseka.Application.DTOs.Client;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Trip
{
    public class TripOfferDTO
    {
        public string TripId { get; set; }
        public LocationDTO StartLocation { get; set; }
        public LocationDTO EndLocation { get; set; }
        public decimal Price { get; set; }
        public DateTime CreatedAt { get; set; }
        public ClientTripDataDTO Client { get; set; }
        public string PaymentMethod { get; set; } = "Cash";
    }

    
}
