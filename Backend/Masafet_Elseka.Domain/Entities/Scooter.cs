using Masafet_Elseka.Domain.Enums;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Domain.Entities
{
    public class Scooter
    {
        public string Id { get; set; }
        public ScooterType Type { get; set; }
        public string? License { get; set; }

        public string DriverId { get; set; }
        public virtual ApplicationUser Driver { get; set; }

    }
}
