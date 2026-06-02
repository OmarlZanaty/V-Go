using Masafet_Elseka.Domain.Enums;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Trip
{
    public class TripResponseDTO
    {
        public string Id { get; set; }
        public decimal Price { get; set; }
        public double StartLat { get; set; }
        public double StartLng { get; set; }
        public double EndLat { get; set; }
        public double EndLng { get; set; }
        public double DistanceInKm { get; set; }
        public string? StartAddress { get; set; }
        public string? EndAddress { get; set; }
        public TripStatus Status { get; set; }
        public DateTime CreatedAt { get; set; }

        // CLeint Data
        public string ClientId { get; set; }
        public string ClientName { get; set; }
        public string ClientGender { get; set; }
        public string ClientPhone { get; set; }
        public string ClientProfilePicture { get; set; }
        public double ClientRating { get; set; }
        public int ClientRatingCount { get; set; }
    }
}
