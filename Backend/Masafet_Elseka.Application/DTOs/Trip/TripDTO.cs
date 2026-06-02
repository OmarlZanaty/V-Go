using Masafet_Elseka.Application.DTOs.RateDTOs;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Trip
{
    public class TripDTO
    {
        public string Id { get; set; }
        public LocationDTO From { get; set; }
        public LocationDTO To { get; set; }
        public DateTime Date { get; set; }
        public decimal? Price { get; set; }
    }
}
