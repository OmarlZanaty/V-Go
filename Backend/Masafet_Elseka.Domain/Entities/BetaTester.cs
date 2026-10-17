using Masafet_Elseka.Domain.Enums;

namespace Masafet_Elseka.Domain.Entities
{
    public class BetaTester
    {
        // String IDs round-trip unchanged through the external JavaScript daemon.
        public string Id { get; set; } = Guid.NewGuid().ToString("N");
        public string Email { get; set; } = string.Empty;
        public string? GoogleSub { get; set; }
        public string Source { get; set; } = "landing";
        public BetaTesterStatus Status { get; set; } = BetaTesterStatus.Invited;
        public bool PlaySynced { get; set; }
        public string? PlayError { get; set; }
        public int SyncAttempts { get; set; }
        public DateTime EnrolledAt { get; set; }
        public DateTime? LastCheckedAt { get; set; }
        public DateTime? RemindedAt { get; set; }
    }
}
