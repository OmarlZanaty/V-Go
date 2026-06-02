using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Driver
{
    public class DriverAlertDataDTO
    {
        public string Id { get; set; }
        public string Name { get; set; }
        public string PhoneNumber { get; set; }
        public string ProfilePicture { get; set; }
        public double Latitude { get; set; }
        public double Longitude { get; set; }
        public DateTime AlertTime { get; set; }
    }
}
