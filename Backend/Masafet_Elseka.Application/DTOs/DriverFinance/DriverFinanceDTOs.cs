namespace Masafet_Elseka.Application.DTOs.DriverFinance
{
    public class DriverFinanceSettingsDTO
    {
        // The company's cut of each fare, in percent (the captain keeps the rest).
        public decimal CompanyCommissionPercent { get; set; }
        // Debt at or above this blocks the captain from going online. 0 disables the lock.
        public decimal CashLimit { get; set; }
        // Warn the captain once his debt reaches this percent of the limit.
        public int WarningPercent { get; set; }
        public DateTime? LedgerStartAt { get; set; }
    }

    public class PeriodTotalsDTO
    {
        public int Trips { get; set; }
        public decimal GrossFare { get; set; }
        public decimal CompanyCommission { get; set; }
        public decimal DriverNet { get; set; }
        // Fares the captain collected in cash / that the company collected online.
        public decimal CashCollected { get; set; }
        public decimal OnlineCollected { get; set; }
    }

    public class OnlineEligibilityDTO
    {
        public bool CanGoOnline { get; set; }
        // null when allowed; otherwise one of: NOT_DRIVER, BLOCKED, SUSPENDED, KYC_PENDING,
        // KYC_UNDER_REVIEW, KYC_REJECTED, DOCS_OVERDUE, CASH_LIMIT.
        public string? Code { get; set; }
        public string? Message { get; set; }
    }

    public class DriverFinanceSummaryDTO
    {
        public string DriverId { get; set; } = string.Empty;
        public string? DriverName { get; set; }

        // Signed: + the company owes the captain, - the captain owes the company.
        public decimal Balance { get; set; }
        public decimal OwedToCompany { get; set; }
        public decimal OwedToDriver { get; set; }

        public decimal CompanyCommissionPercent { get; set; }
        public decimal CashLimit { get; set; }
        public int WarningPercent { get; set; }
        // Debt as a percent of the limit (0 when the lock is disabled).
        public decimal LimitUsedPercent { get; set; }
        public bool IsNearLimit { get; set; }
        public bool IsLocked { get; set; }

        public PeriodTotalsDTO Today { get; set; } = new();
        public PeriodTotalsDTO Week { get; set; } = new();
        public PeriodTotalsDTO Month { get; set; } = new();
        public PeriodTotalsDTO AllTime { get; set; } = new();

        public string? PayoutMethod { get; set; }
        public string? PayoutAccount { get; set; }
        public string? PayoutAccountName { get; set; }
        public DateTime? PayoutUpdatedAt { get; set; }

        public string VerificationStatus { get; set; } = string.Empty;
        public OnlineEligibilityDTO Eligibility { get; set; } = new();
    }

    public class LedgerEntryDTO
    {
        public long Id { get; set; }
        public string Type { get; set; } = string.Empty;
        public decimal Amount { get; set; }
        public string? TripId { get; set; }
        public decimal? TripFare { get; set; }
        public decimal? CommissionPercent { get; set; }
        public decimal? CommissionAmount { get; set; }
        // Captain's net from the trip (fare - commission); null for non-trip entries.
        public decimal? DriverNet { get; set; }
        public string? TripPaymentMethod { get; set; }
        public string? PaymentId { get; set; }
        public string Description { get; set; } = string.Empty;
        public string? Reference { get; set; }
        public string? AttachmentUrl { get; set; }
        public string? CreatedByName { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    public class SettlementIntentDTO
    {
        public string PaymentId { get; set; } = string.Empty;
        public decimal Amount { get; set; }
        public string ClientSecret { get; set; } = string.Empty;
        public string? PublicKey { get; set; }
        public string CheckoutUrl { get; set; } = string.Empty;
    }

    public class SettlementStatusDTO
    {
        public string PaymentId { get; set; } = string.Empty;
        public decimal Amount { get; set; }
        public string Status { get; set; } = string.Empty;
        public bool Credited { get; set; }
        public decimal Balance { get; set; }
        public bool CanGoOnline { get; set; }
    }

    public class SetPayoutAccountDTO
    {
        // "InstaPay" or "MobileWallet"
        public string Method { get; set; } = string.Empty;
        public string Account { get; set; } = string.Empty;
        public string AccountName { get; set; } = string.Empty;
        // Current account password, so a stolen session can't redirect payouts.
        public string Password { get; set; } = string.Empty;
    }

    public class AdjustmentRequestDTO
    {
        // Signed: + bonus to the captain, - penalty / extra charge.
        public decimal Amount { get; set; }
        public string Reason { get; set; } = string.Empty;
    }

    public class PayoutRequestDTO
    {
        public decimal Amount { get; set; }
        public string Reference { get; set; } = string.Empty;
        public string? Note { get; set; }
    }

    public class AdminDriverFinanceRowDTO
    {
        public string DriverId { get; set; } = string.Empty;
        public string? Name { get; set; }
        public string? Phone { get; set; }
        public string? ProfilePicture { get; set; }
        public decimal Balance { get; set; }
        public bool IsLocked { get; set; }
        public bool IsNearLimit { get; set; }
        public bool IsAvailable { get; set; }
        public string VerificationStatus { get; set; } = string.Empty;
        public string? PayoutMethod { get; set; }
        public string? PayoutAccount { get; set; }
        public string? PayoutAccountName { get; set; }
        public DateTime? LastEntryAt { get; set; }
    }

    public class FinanceOverviewDTO
    {
        // Sum of all captain debts to the company / all company debts to captains.
        public decimal TotalOwedToCompany { get; set; }
        public decimal TotalOwedToDrivers { get; set; }
        public int LockedDrivers { get; set; }
        public int NearLimitDrivers { get; set; }
        public int DriversAwaitingPayout { get; set; }
        public decimal SettledThisMonth { get; set; }
        public decimal PaidOutThisMonth { get; set; }
        public decimal CommissionThisMonth { get; set; }
    }

    public class SettlementRowDTO
    {
        public string PaymentId { get; set; } = string.Empty;
        public string DriverId { get; set; } = string.Empty;
        public string? DriverName { get; set; }
        public string? DriverPhone { get; set; }
        public decimal Amount { get; set; }
        public string Status { get; set; } = string.Empty;
        public bool Credited { get; set; }
        public string? Method { get; set; }
        public string? TransactionId { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
    }

    public class AuditLogDTO
    {
        public long Id { get; set; }
        public string ActorUserId { get; set; } = string.Empty;
        public string? ActorName { get; set; }
        public string Action { get; set; } = string.Empty;
        public string? TargetUserId { get; set; }
        public string? TargetName { get; set; }
        public string? Details { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
