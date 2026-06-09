using Masafet_Elseka.Domain.Enums;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Domain.Entities
{
    public class Payment
    {
        public string Id { get; set; } = Guid.NewGuid().ToString();
        public decimal Amount { get; set; }
        public string Currency { get; set; } = "EGP";
        public string? Method { get; set; }
        public PaymentStatus Status { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; }
        public string? OrderId { get; set; }
        public string? TransactionId { get; set; }

        // Visa pre-authorization fields. Set as the Auth & Capture flow progresses;
        // null for cash and legacy immediate-sale payments.
        public string? PreauthTransactionId { get; set; }
        public string? CaptureTransactionId { get; set; }
        public string? FailureReason { get; set; }
        // When the Paymob hold expires (createdAt + 6 days). The expiry cron voids
        // any still-held pre-auth past this time so we never leave funds frozen.
        public DateTime? PreauthExpiresAt { get; set; }

        public string UserId { get; set; }
        public string TripId { get; set; }

        [ForeignKey("UserId")]
        public virtual ApplicationUser User { get; set; }
        [ForeignKey("TripId")]
        public virtual Trip Trip { get; set; }
    }
}
