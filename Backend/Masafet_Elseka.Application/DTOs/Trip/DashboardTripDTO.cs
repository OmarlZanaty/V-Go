using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Trip
{
    public class DashboardTripDTO
    {
        public string TripId { get; set; }
        public string From { get; set; }
        public string To { get; set; }
        public decimal Price { get; set; }
        public double? DistanceKm { get; set; }
        public string Status { get; set; }
        public string ClientName { get; set; }
        public string? DriverName { get; set; }
        public DateTime CreatedAt { get; set; }
        public decimal? DriverRate { get; set; }
        public decimal? ClientRate { get; set; }
        // Coordinates for the live admin map.
        public double FromLat { get; set; }
        public double FromLng { get; set; }
        public double ToLat { get; set; }
        public double ToLng { get; set; }
        public string? DriverId { get; set; }
        public double? DriverLat { get; set; }
        public double? DriverLng { get; set; }
    }
}
