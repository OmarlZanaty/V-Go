using Masafet_Elseka.Domain.Enums;
using System.ComponentModel.DataAnnotations;

namespace Masafet_Elseka.Domain.Entities
{
    // A company wallet number captains transfer their dues to. Its SIM sits in a
    // phone running the V-Go Collector app, which relays the receipt SMS.
    public class CollectionWallet
    {
        public int Id { get; set; }
        public WalletProvider Provider { get; set; }
        [MaxLength(20)]
        public string PhoneNumber { get; set; } = string.Empty;
        [MaxLength(100)]
        public string HolderName { get; set; } = string.Empty;
        public bool IsActive { get; set; } = true;
        public int SortOrder { get; set; }
        // The collector phone holding this SIM (null = not assigned yet).
        public Guid? DeviceId { get; set; }
        public DateTime? LastSmsAt { get; set; }
        public DateTime CreatedAt { get; set; }

        public virtual CollectorDevice? Device { get; set; }
    }
}
