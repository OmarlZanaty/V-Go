using Masafet_Elseka.Domain.Enums;
using System.ComponentModel.DataAnnotations.Schema;

namespace Masafet_Elseka.Domain.Entities
{
    // One immutable line in a captain's account. The balance is the sum of Amount;
    // entries are never edited or deleted — a mistake is fixed by a new entry.
    public class DriverLedgerEntry
    {
        public long Id { get; set; }
        public string DriverId { get; set; }
        public LedgerEntryType Type { get; set; }

        // Signed: + the company owes the captain, - the captain owes the company.
        [Column(TypeName = "decimal(18,2)")]
        public decimal Amount { get; set; }

        // Trip entries keep the numbers they were computed from, so the captain's
        // breakdown stays right even after the admin changes the commission.
        public string? TripId { get; set; }
        [Column(TypeName = "decimal(18,2)")]
        public decimal? TripFare { get; set; }
        [Column(TypeName = "decimal(5,2)")]
        public decimal? CommissionPercent { get; set; }
        [Column(TypeName = "decimal(18,2)")]
        public decimal? CommissionAmount { get; set; }

        // Settlement entries point at the Paymob payment that funded them.
        public string? PaymentId { get; set; }
        // Wallet-collection entries point at the receipt SMS that confirmed them.
        public long? WalletSmsId { get; set; }

        public string Description { get; set; } = string.Empty;
        public string? Reference { get; set; }      // payout transfer reference
        public string? AttachmentUrl { get; set; }  // payout receipt
        public string? CreatedByUserId { get; set; } // admin for manual entries, null for system
        public DateTime CreatedAt { get; set; }

        [ForeignKey(nameof(DriverId))]
        public virtual ApplicationUser Driver { get; set; }
        [ForeignKey(nameof(TripId))]
        public virtual Trip? Trip { get; set; }
    }
}
