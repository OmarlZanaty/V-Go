using Masafet_Elseka.Domain.Enums;
using System.ComponentModel.DataAnnotations.Schema;

namespace Masafet_Elseka.Domain.Entities
{
    // One verification document per captain per type; re-uploading replaces it.
    public class DriverDocument
    {
        public string Id { get; set; } = Guid.NewGuid().ToString();
        public string DriverId { get; set; }
        public DriverDocumentType Type { get; set; }
        public DriverDocumentStatus Status { get; set; }

        // Private files (IDs, licences) are a path under the private storage root and
        // are only served to admins. The selfie is public — it's the profile photo.
        public string FilePath { get; set; } = string.Empty;
        public string ContentType { get; set; } = "image/jpeg";
        public bool IsPublic { get; set; }

        public DateTime? ExpiryDate { get; set; }
        public string? RejectionReason { get; set; }
        public DateTime UploadedAt { get; set; }
        public DateTime? ReviewedAt { get; set; }
        public string? ReviewedByUserId { get; set; }

        [ForeignKey(nameof(DriverId))]
        public virtual ApplicationUser Driver { get; set; }
    }
}
