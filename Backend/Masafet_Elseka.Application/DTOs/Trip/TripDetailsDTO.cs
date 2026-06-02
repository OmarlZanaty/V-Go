using Masafet_Elseka.Application.DTOs.Rating;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Trip
{
    public class TripDetailsDTO
    {
        public string TripId { get; set; }
        public LocationDTO From { get; set; }
        public LocationDTO To { get; set; }
        public decimal Price { get; set; }
        public double? DistanceKm { get; set; }
        public string Status { get; set; }
        public bool IsPaid { get; set; }

        public string UserId { get; set; }
        public string UserName { get; set; } // Full Name 
        public string UserPhone { get; set; }
        public string? UserProfileImage { get; set; }
        public string? DriverId { get; set; }
        public string? DriverName { get; set; }
        public string? DriverPhone { get; set; }
        public string? DriverProfileImage { get; set; }
        public bool? IsArrived { get; set; }
        public string? ScooterType { get; set; }
        public string? ScooterLicense { get; set; }

        public DateTime CreatedAt { get; set; }
        public decimal? DriverRating { get; set; }   
        public decimal? Userrating { get; set; }
        public ICollection<RatingResponseDTO> Ratings { get; set; } = new List<RatingResponseDTO>();

    }

}
