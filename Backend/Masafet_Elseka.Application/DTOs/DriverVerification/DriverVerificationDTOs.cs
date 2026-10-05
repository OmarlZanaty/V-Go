namespace Masafet_Elseka.Application.DTOs.DriverVerification
{
    public class DriverDocumentDTO
    {
        public string Id { get; set; } = string.Empty;
        public string Type { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public DateTime? ExpiryDate { get; set; }
        public string? RejectionReason { get; set; }
        public DateTime UploadedAt { get; set; }
        public DateTime? ReviewedAt { get; set; }
        // Public URL for the selfie; null for private documents (admins fetch those
        // through the authorised file endpoint).
        public string? PublicUrl { get; set; }
    }

    public class DriverVerificationDTO
    {
        public string DriverId { get; set; } = string.Empty;
        public string? Name { get; set; }
        public string? Phone { get; set; }
        public string? ProfilePicture { get; set; }
        public string Status { get; set; } = string.Empty;
        public string? Note { get; set; }
        public DateTime? DocumentsDeadline { get; set; }
        public List<DriverDocumentDTO> Documents { get; set; } = new();
        // Document types still to upload (or re-upload after a rejection).
        public List<string> MissingTypes { get; set; } = new();
        public List<string> RequiredTypes { get; set; } = new();
        public bool CanGoOnline { get; set; }
        public string? BlockCode { get; set; }
        public string? BlockMessage { get; set; }
    }

    public class VerificationQueueItemDTO
    {
        public string DriverId { get; set; } = string.Empty;
        public string? Name { get; set; }
        public string? Phone { get; set; }
        public string? ProfilePicture { get; set; }
        public string Status { get; set; } = string.Empty;
        public int UploadedCount { get; set; }
        public int PendingCount { get; set; }
        public int RejectedCount { get; set; }
        public DateTime? LastUploadAt { get; set; }
        public DateTime? DocumentsDeadline { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    public class ReviewDocumentDTO
    {
        public bool Approve { get; set; }
        public string? Reason { get; set; }
    }

    public class VerificationDecisionDTO
    {
        // "Approved", "Rejected" or "Suspended"
        public string Status { get; set; } = string.Empty;
        public string? Note { get; set; }
    }

    public class DocumentFileDTO
    {
        public byte[] Content { get; set; } = Array.Empty<byte>();
        public string ContentType { get; set; } = "image/jpeg";
        public string FileName { get; set; } = "document.jpg";
    }
}
