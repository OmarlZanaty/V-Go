namespace Masafet_Elseka.Domain.Entities
{
    // One daily collection round, keyed by the Egypt date of its evening notice.
    // Each phase is claimed with an atomic update so it runs exactly once even
    // across restarts or several backend instances.
    public class CollectionCycle
    {
        public int Id { get; set; }
        public DateTime CycleDate { get; set; }
        public DateTime? NoticeSentAt { get; set; }
        public int NoticeCount { get; set; }
        public DateTime? ReminderSentAt { get; set; }
        public int ReminderCount { get; set; }
        public DateTime? LockAppliedAt { get; set; }
        public int LockedCount { get; set; }
        public string? LockNote { get; set; }
    }
}
