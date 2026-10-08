namespace Masafet_Elseka.Application.DTOs.Collection
{
    // ===================== Captain =====================

    public class CollectionWalletDTO
    {
        public int Id { get; set; }
        public string Provider { get; set; } = string.Empty;      // VodafoneCash | EtisalatCash | InstaPay
        public string ProviderLabel { get; set; } = string.Empty; // فودافون كاش ...
        // Mobile number, or the InstaPay address for InstaPay.
        public string PhoneNumber { get; set; } = string.Empty;
        public string HolderName { get; set; } = string.Empty;
        public string? BankName { get; set; }
        // The collector phone holding this SIM reported in recently, so a transfer
        // will be confirmed within minutes.
        public bool IsOnline { get; set; }
    }

    public class CollectionRequestDTO
    {
        public long Id { get; set; }
        public int WalletId { get; set; }
        public string? WalletPhone { get; set; }
        public string? Provider { get; set; }
        public string? SenderPhone { get; set; }
        public string? SenderAccount { get; set; }
        public string? SenderName { get; set; }
        public decimal Amount { get; set; }
        public string Status { get; set; } = string.Empty; // Pending | Confirmed | NeedsReview | Rejected | Expired | Cancelled
        public string? Note { get; set; }
        public decimal? ReceivedAmount { get; set; }        // what the receipt SMS said, once matched
        public DateTime CreatedAt { get; set; }
        public DateTime? ResolvedAt { get; set; }
    }

    public class MyCollectionDTO
    {
        public bool Enabled { get; set; }
        public decimal OwedToCompany { get; set; }
        public decimal Tolerance { get; set; }
        // Owes more than the tolerance: has to transfer before the deadline.
        public bool MustPay { get; set; }
        public int NoticeHour { get; set; }
        public int DeadlineHour { get; set; }
        // The deadline of the round in progress, or of the next one.
        public DateTime DeadlineAt { get; set; }
        // Between the evening notice and the deadline right now.
        public bool InWindow { get; set; }
        public bool IsLocked { get; set; }
        public DateTime? LockedSince { get; set; }
        public List<CollectionWalletDTO> Wallets { get; set; } = new();
        public CollectionRequestDTO? Pending { get; set; }
        public List<CollectionRequestDTO> Recent { get; set; } = new();
        public string? LastSenderPhone { get; set; }
        public string? LastSenderAccount { get; set; }
        public string? LastSenderName { get; set; }
        public DateTime ServerTime { get; set; }
    }

    public class CreateCollectionRequestDTO
    {
        public int WalletId { get; set; }
        // Mobile wallets: required. InstaPay: the sending address and / or number, plus
        // the name it shows (at least one of the three).
        public string? SenderPhone { get; set; }
        public string? SenderAccount { get; set; }
        public string? SenderName { get; set; }
        public decimal Amount { get; set; }
    }

    // ===================== Collector phone =====================

    public class CollectorPairDTO
    {
        public string Code { get; set; } = string.Empty;
        public string? DeviceName { get; set; }
        public string? AppVersion { get; set; }
    }

    public class CollectorPairResultDTO
    {
        public Guid DeviceId { get; set; }
        public string DeviceKey { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
    }

    public class CollectorHeartbeatDTO
    {
        public string? AppVersion { get; set; }
        public int? Battery { get; set; }
        public bool? Charging { get; set; }
        public bool? SmsPermission { get; set; }
        public bool? NotificationAccess { get; set; } // InstaPay notifications
        public int? Pending { get; set; }       // messages queued on the phone, not yet uploaded
        public long? LastInboxId { get; set; }
        public string? LastError { get; set; }
    }

    public class CollectorWalletDTO
    {
        public int Id { get; set; }
        public string Provider { get; set; } = string.Empty;
        public string PhoneNumber { get; set; } = string.Empty;
    }

    public class CollectorConfigDTO
    {
        public string DeviceName { get; set; } = string.Empty;
        public DateTime ServerTime { get; set; }
        public List<string> SenderHints { get; set; } = new();
        // SMS / notifications containing one of these are forwarded whatever the sender.
        public List<string> InstaPayKeywords { get; set; } = new();
        // Apps whose notifications are forwarded.
        public List<string> NotificationPackages { get; set; } = new();
        public List<CollectorWalletDTO> Wallets { get; set; } = new();
        // How far back the phone re-scans its inbox for anything it might have missed.
        public int LookbackHours { get; set; }
        public int HeartbeatSeconds { get; set; }
    }

    public class CollectorSmsDTO
    {
        public string ClientId { get; set; } = string.Empty;
        public string Sender { get; set; } = string.Empty;
        public string Body { get; set; } = string.Empty;
        public long ReceivedAtMs { get; set; } // unix epoch milliseconds from the phone
        public string? Source { get; set; }    // "sms" (default) | "notification"
        public string? Package { get; set; }   // notifications: the posting app
    }

    public class CollectorSmsBatchDTO
    {
        public List<CollectorSmsDTO> Messages { get; set; } = new();
    }

    public class CollectorSmsResultDTO
    {
        public string ClientId { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty; // stored | duplicate | rejected
        public long? Id { get; set; }
        public string? Kind { get; set; }
        public string? MatchStatus { get; set; }
    }

    // ===================== Admin =====================

    public class AdminCollectionRequestDTO : CollectionRequestDTO
    {
        public string DriverId { get; set; } = string.Empty;
        public string? DriverName { get; set; }
        public string? DriverPhone { get; set; }
        public decimal DebtAtRequest { get; set; }
        public long? WalletSmsId { get; set; }
        public string? ResolvedByName { get; set; }
    }

    public class WalletSmsDTO
    {
        public long Id { get; set; }
        public string? DeviceName { get; set; }
        public string Sender { get; set; } = string.Empty;
        public string Body { get; set; } = string.Empty;
        public DateTime ReceivedAt { get; set; }
        public DateTime IngestedAt { get; set; }
        public string? Provider { get; set; }
        public string? WalletPhone { get; set; }
        public string Kind { get; set; } = string.Empty;
        public decimal? Amount { get; set; }
        public string? CounterpartyPhone { get; set; }
        public string? CounterpartyAccount { get; set; }
        public string? CounterpartyName { get; set; }
        public string Source { get; set; } = "Sms";
        public string? SourcePackage { get; set; }
        public string? TxnRef { get; set; }
        public decimal? BalanceAfter { get; set; }
        public string MatchStatus { get; set; } = string.Empty;
        public long? CollectionRequestId { get; set; }
        public string? DriverId { get; set; }
        public string? DriverName { get; set; }
        public string? Note { get; set; }
        public string? ReviewedByName { get; set; }
        public DateTime? ReviewedAt { get; set; }
    }

    public class AssignSmsDTO
    {
        // Either the captain request it settles, or the captain to credit directly.
        public long? RequestId { get; set; }
        public string? DriverId { get; set; }
        public string? Note { get; set; }
    }

    public class ReviewNoteDTO
    {
        public string? Note { get; set; }
    }

    public class WalletUpsertDTO
    {
        public string Provider { get; set; } = string.Empty;
        public string PhoneNumber { get; set; } = string.Empty;
        public string HolderName { get; set; } = string.Empty;
        public string? BankName { get; set; }
        public bool IsActive { get; set; } = true;
        public int SortOrder { get; set; }
        public Guid? DeviceId { get; set; }
    }

    public class AdminWalletDTO : CollectionWalletDTO
    {
        public bool IsActive { get; set; }
        public int SortOrder { get; set; }
        public Guid? DeviceId { get; set; }
        public string? DeviceName { get; set; }
        public DateTime? LastSmsAt { get; set; }
    }

    public class CollectorDeviceDTO
    {
        public Guid Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public bool IsActive { get; set; }
        public bool Paired { get; set; }
        public string? PairingCode { get; set; }
        public DateTime? PairingExpiresAt { get; set; }
        public DateTime? PairedAt { get; set; }
        public DateTime? LastSeenAt { get; set; }
        public bool Online { get; set; }
        public string? AppVersion { get; set; }
        public string? LastStatus { get; set; }
        public List<string> Wallets { get; set; } = new();
    }

    public class CreateDeviceDTO
    {
        public string Name { get; set; } = string.Empty;
    }

    public class CollectionCycleDTO
    {
        public DateTime CycleDate { get; set; }
        public DateTime? NoticeSentAt { get; set; }
        public int NoticeCount { get; set; }
        public DateTime? ReminderSentAt { get; set; }
        public int ReminderCount { get; set; }
        public DateTime? LockAppliedAt { get; set; }
        public int LockedCount { get; set; }
        public string? LockNote { get; set; }
    }

    public class CollectionOverviewDTO
    {
        public bool Enabled { get; set; }
        public decimal Tolerance { get; set; }
        public int NoticeHour { get; set; }
        public int DeadlineHour { get; set; }
        public int PendingRequests { get; set; }
        public int ReviewRequests { get; set; }
        public int UnclaimedSms { get; set; }
        public int ReviewSms { get; set; }
        public decimal CollectedToday { get; set; }
        public int CollectedTodayCount { get; set; }
        public int LockedDrivers { get; set; }
        public int MustPayDrivers { get; set; }
        public decimal TotalDueAboveTolerance { get; set; }
        public int OnlineDevices { get; set; }
        public int ActiveWallets { get; set; }
        public List<CollectionCycleDTO> RecentCycles { get; set; } = new();
    }
}
