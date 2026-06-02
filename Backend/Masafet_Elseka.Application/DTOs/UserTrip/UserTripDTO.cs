using Masafet_Elseka.Domain.Enums;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.UserTripDTO
{
    public class UserTripDTO
    {
        public UserTripRole Role { get; set; }
        public string UserId { get; set; }
        public string TripId { get; set; }
    }
}
