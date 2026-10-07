using System.ComponentModel.DataAnnotations;

namespace Masafet_Elseka.Domain.Entities
{
    // A company phone running the V-Go Collector app. It pairs once with a short
    // code from the dashboard and then authenticates with a device key.
    public class CollectorDevice
    {
        public Guid Id { get; set; }
        [MaxLength(100)]
        public string Name { get; set; } = string.Empty;
        // SHA-256 (hex) of the device key; null until paired.
        [MaxLength(64)]
        public string? KeyHash { get; set; }
        [MaxLength(12)]
        public string? PairingCode { get; set; }
        public DateTime? PairingExpiresAt { get; set; }
        public bool IsActive { get; set; } = true;
        public DateTime? PairedAt { get; set; }
        public DateTime? LastSeenAt { get; set; }
        [MaxLength(40)]
        public string? AppVersion { get; set; }
        // Last heartbeat details (battery, SMS permission, queue size...) as JSON.
        [MaxLength(1000)]
        public string? LastStatus { get; set; }
        public DateTime CreatedAt { get; set; }
        public string? CreatedByUserId { get; set; }
    }
}
