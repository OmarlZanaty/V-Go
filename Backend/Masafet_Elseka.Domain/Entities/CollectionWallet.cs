using Masafet_Elseka.Domain.Enums;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Masafet_Elseka.Domain.Entities
{
    // A company wallet number captains transfer their dues to. Its SIM sits in a
    // phone running the V-Go Collector app, which relays the receipt SMS.
    public class CollectionWallet
    {
        public int Id { get; set; }
        public WalletProvider Provider { get; set; }
        // Wallet mobile number, or the InstaPay address (name@instapay) for InstaPay.
        [MaxLength(100)]
        public string PhoneNumber { get; set; } = string.Empty;
        [MaxLength(100)]
        public string HolderName { get; set; } = string.Empty;
        // InstaPay: the bank behind the address, shown to the captain.
        [MaxLength(100)]
        public string? BankName { get; set; }
        public bool IsActive { get; set; } = true;
        public int SortOrder { get; set; }
        // The collector phone holding this SIM (null = not assigned yet).
        public Guid? DeviceId { get; set; }
        public DateTime? LastSmsAt { get; set; }
        // Which SIM of a dual-SIM collector phone holds this wallet (1 / 2); null =
        // the only wallet of its kind on that phone.
        public int? SimSlot { get; set; }

        // Balance chain (anti-forgery): the balance the next receipt must start from,
        // how many receipts in a row didn't follow it, and the pause after three.
        [Column(TypeName = "decimal(18,2)")]
        public decimal? ExpectedBalance { get; set; }
        public int GapStreak { get; set; }
        // Time of the newest message on the chain (older arrivals don't move it).
        public DateTime? LastChainAt { get; set; }
        [MaxLength(200)]
        public string? PausedReason { get; set; }
        public DateTime? PausedAt { get; set; }
        public DateTime CreatedAt { get; set; }

        public virtual CollectorDevice? Device { get; set; }
    }
}
