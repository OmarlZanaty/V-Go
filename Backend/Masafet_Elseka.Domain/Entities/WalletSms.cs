using Masafet_Elseka.Domain.Enums;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Masafet_Elseka.Domain.Entities
{
    // One SMS relayed by a collector phone, with what the parser read from it and
    // how it was reconciled. The raw body is kept for audits and re-parsing.
    public class WalletSms
    {
        public long Id { get; set; }
        public Guid DeviceId { get; set; }
        // Stable id from the phone (inbox id + timestamp) so retries never duplicate.
        [MaxLength(100)]
        public string ClientId { get; set; } = string.Empty;
        [MaxLength(60)]
        public string Sender { get; set; } = string.Empty;
        [MaxLength(2000)]
        public string Body { get; set; } = string.Empty;
        public DateTime ReceivedAt { get; set; }  // when the phone got it (Egypt time)
        public DateTime IngestedAt { get; set; }

        public WalletProvider? Provider { get; set; }
        public int? WalletId { get; set; }
        public WalletSmsKind Kind { get; set; }
        [Column(TypeName = "decimal(18,2)")]
        public decimal? Amount { get; set; }
        [MaxLength(20)]
        public string? CounterpartyPhone { get; set; }
        [MaxLength(60)]
        public string? TxnRef { get; set; }
        [Column(TypeName = "decimal(18,2)")]
        public decimal? BalanceAfter { get; set; }

        public WalletSmsMatchStatus MatchStatus { get; set; }
        public long? CollectionRequestId { get; set; }
        public string? DriverId { get; set; }   // who it was credited to
        [MaxLength(500)]
        public string? Note { get; set; }
        public string? ReviewedByUserId { get; set; }
        public DateTime? ReviewedAt { get; set; }

        public virtual CollectorDevice? Device { get; set; }
        public virtual CollectionWallet? Wallet { get; set; }
    }
}
