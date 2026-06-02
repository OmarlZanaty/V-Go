using Masafet_Elseka.Domain.Enums;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Domain.Entities
{
    public class Trip
    {
        public string Id { get; set; }
        public decimal Price { get; set; }
        public double StartLat { get; set; }
        public double StartLng { get; set; }
        public double EndLat { get; set; }
        public double EndLng { get; set; }
        public double DistanceInKm { get; set; }
        public string? StartAddress { get; set;}
        public string? EndAddress { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? StartTime { get; set; }
        public DateTime? EndTime { get; set; }
        public TripStatus Status { get; set; }

        [Timestamp] 
        public byte[] RowVersion { get; set; }

        public virtual Chat? Chat { get; set; }
        public virtual ICollection<Payment> Payment { get; set; } = new List<Payment>();
        public virtual ICollection<Rate> UserRates { get; set; }
        public virtual ICollection<UserTrip> UserTrips { get; set; } = new List<UserTrip>();


    }
}
