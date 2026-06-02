using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Domain.Entities
{
    public class PricingRule
    {
        public int Id { get; set; }
        public decimal PricePerKm { get; set; } = 0;
        public decimal DriverCommissionPercentage { get; set; } = 0;
        public DateTime LastUpdated { get; set; }

    }
}
