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

        // Captain finance. Debt at or above CashLimit blocks the captain from going
        // online; 0 disables the lock. WarningPercent of the limit triggers a heads-up.
        [System.ComponentModel.DataAnnotations.Schema.Column(TypeName = "decimal(18,2)")]
        public decimal CashLimit { get; set; } = 1000;
        public int WarningPercent { get; set; } = 80;
        // Trips that ended before this moment are not posted to captain ledgers.
        public DateTime? LedgerStartAt { get; set; }

    }
}
