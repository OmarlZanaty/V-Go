namespace Masafet_Elseka.Domain.Entities
{
    // Who did what from the dashboard (finance settings, payouts, adjustments, approvals).
    public class AdminAuditLog
    {
        public long Id { get; set; }
        public string ActorUserId { get; set; } = string.Empty;
        public string? ActorName { get; set; }
        public string Action { get; set; } = string.Empty;
        public string? TargetUserId { get; set; }
        public string? Details { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
