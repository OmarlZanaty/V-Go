using System.ComponentModel.DataAnnotations;

namespace Masafet_Elseka.Domain.Entities
{
    public class PhoneOtp
    {
        public Guid Id { get; set; }
        [MaxLength(450)]
        public string UserId { get; set; } = string.Empty;
        [MaxLength(32)]
        public string Phone { get; set; } = string.Empty;
        [MaxLength(20)]
        public string Purpose { get; set; } = "reset";
        [MaxLength(64)]
        public string CodeHash { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
        public DateTime ExpiresAt { get; set; }
        public int Attempts { get; set; }
        public DateTime? ConsumedAt { get; set; }
        [MaxLength(64)]
        public string? ResetTokenHash { get; set; }
        public DateTime? ResetTokenExpiresAt { get; set; }
        public DateTime? ResetTokenUsedAt { get; set; }
    }
}
