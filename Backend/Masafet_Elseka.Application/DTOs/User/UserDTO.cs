using Masafet_Elseka.Application.DTOs.RateDTOs;
using Masafet_Elseka.Application.DTOs.Trip;
using Masafet_Elseka.Domain.Entities;
using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.User
{
    public class UserDTO
    {
        public string Id { get; set; }
        public string Name { get; set; }
        public string? PhoneNumber { get; set; }
        public string Email { get; set; }
        public IList<string> Roles { get; set; }
        public string Gender { get; set; }
        public string? NationalId { get; set; }
        public string? ProfilePicture { get; set; }
        public int TripCount { get; set; }
        public bool IsBlocked { get; set; }
        public decimal? Rate { get; set; }
    }
}
