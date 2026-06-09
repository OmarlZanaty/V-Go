using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Trip
{
    public class TripRequest
    {
        [JsonPropertyName("startLat")]
        public double StartLat { get; set; }
        [JsonPropertyName("startLng")]
        public double StartLng { get; set; }
        [JsonPropertyName("endLat")]
        public double EndLat { get; set; }
        [JsonPropertyName("endLng")]
        public double EndLng { get; set; }
        public string? StartAddress { get; set; }
        public string? EndAddress { get; set; }
        public double Distance { get; set; }
        public string UserId { get; set; }
        // "Cash" or "Visa" — chosen by the client before searching for a captain.
        public string? PaymentMethod { get; set; }
    }
}
