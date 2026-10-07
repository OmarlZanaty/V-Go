using Masafet_Elseka.Domain.Enums;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Masafet_Elseka.Domain.Entities
{
    // The captain's statement "I transferred Amount from SenderPhone to wallet X".
    // It is confirmed only when a receipt SMS with the same sender and amount arrives.
    public class CollectionRequest
    {
        public long Id { get; set; }
        public string DriverId { get; set; } = string.Empty;
        public int WalletId { get; set; }
        [MaxLength(20)]
        public string SenderPhone { get; set; } = string.Empty;
        [Column(TypeName = "decimal(18,2)")]
        public decimal Amount { get; set; }
        [Column(TypeName = "decimal(18,2)")]
        public decimal DebtAtRequest { get; set; }
        public CollectionRequestStatus Status { get; set; }
        public long? WalletSmsId { get; set; }
        [MaxLength(500)]
        public string? Note { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? ResolvedAt { get; set; }
        public string? ResolvedByUserId { get; set; }

        public virtual ApplicationUser Driver { get; set; } = null!;
        public virtual CollectionWallet Wallet { get; set; } = null!;
    }
}
