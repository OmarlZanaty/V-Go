using System.ComponentModel.DataAnnotations;

namespace Masafet_Elseka.Domain.Entities
{
    public class SmsOutbox
    {
        public Guid Id { get; set; }
        [MaxLength(32)]
        public string To { get; set; } = string.Empty;
        [MaxLength(320)]
        public string Body { get; set; } = string.Empty;
        [MaxLength(20)]
        public string Purpose { get; set; } = "reset";
        [MaxLength(16)]
        public string Status { get; set; } = "Pending";
        public int Attempts { get; set; }
        public Guid? ClaimedByDeviceId { get; set; }
        public DateTime? ClaimedAt { get; set; }
        public DateTime? SentAt { get; set; }
        [MaxLength(24)]
        public string? DeliveryStatus { get; set; }
        public DateTime? DeliveryReportAt { get; set; }
        [MaxLength(300)]
        public string? Error { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime ExpiresAt { get; set; }
    }
}
