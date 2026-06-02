using Masafet_Elseka.Application.DTOs.RateDTOs;
using Masafet_Elseka.Application.DTOs.Trip;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Driver
{
    public class DriverDTO
    {
        public string Id { get; set; }
        public string Name { get; set; }
        public string? PhoneNumber { get; set; }
        public string Email { get; set; }
        public string Gender { get; set; }
        public string NationalId { get; set; }
        public string License { get; set; }
        public string? ProfilePicture { get; set; }
        public bool IsAvailable { get; set; } 
        public bool IsBlocked { get; set; }
        public ScooterType ScooterType { get; set; }
        public string? ScooterLicense { get; set; }
        public int TripCount { get; set; } = 0;
        public decimal? Rate { get; set; }
        public List<string> Roles { get; set; }
        public Dictionary<string, decimal> Profit { get; set; } = new();

    }
}
