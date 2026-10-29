namespace Masafet_Elseka.Application.DTOs.Collection
{
    public class SmsOutboxMessageDTO
    {
        public Guid Id { get; set; }
        public string To { get; set; } = string.Empty;
        public string Body { get; set; } = string.Empty;
    }

    public class SmsDeliveryDTO
    {
        public bool Delivered { get; set; }
        [System.ComponentModel.DataAnnotations.MaxLength(40)]
        public string? Status { get; set; }
    }

    public class SmsOutboxAdminDTO
    {
        public Guid Id { get; set; }
        public string To { get; set; } = string.Empty;
        public string Purpose { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public int Attempts { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? ClaimedAt { get; set; }
        public DateTime? SentAt { get; set; }
        public string? DeliveryStatus { get; set; }
        public DateTime? DeliveryReportAt { get; set; }
        public string? Error { get; set; }
        public string? DeviceName { get; set; }
    }

    public class SmsOutboxResultDTO
    {
        public bool Sent { get; set; }
        public string? Error { get; set; }
    }
}
