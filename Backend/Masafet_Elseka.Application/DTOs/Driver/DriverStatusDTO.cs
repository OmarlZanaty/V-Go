using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Driver
{
    public class DriverStatusDTO
    {
        public string DriverId { get; set; }
        public string? DriverName { get; set; }
        public string? DriverGender { get; set; }
        public bool IsAvailable { get; set; }
        public string? ProfilePhoto { get; set; }
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
    }
}
