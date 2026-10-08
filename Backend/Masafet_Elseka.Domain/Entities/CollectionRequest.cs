using Masafet_Elseka.Domain.Enums;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Masafet_Elseka.Domain.Entities
{
    // The captain's statement "I transferred Amount from SenderPhone / SenderAccount to
    // wallet X". It is confirmed only when a receipt with the same amount and a matching
    // sender arrives.
    public class CollectionRequest
    {
        public long Id { get; set; }
        public string DriverId { get; set; } = string.Empty;
        public int WalletId { get; set; }
        // Mobile wallet transfers: the sending number. InstaPay: optional.
        [MaxLength(20)]
        public string? SenderPhone { get; set; }
        // InstaPay: the sending address (name@instapay) and the name it shows.
        [MaxLength(100)]
        public string? SenderAccount { get; set; }
        [MaxLength(100)]
        public string? SenderName { get; set; }
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
