using Masafet_Elseka.Application.Common.Pagination;
using Masafet_Elseka.Application.DTOs.DriverFinance;
using Masafet_Elseka.Application.Response;

namespace Masafet_Elseka.Application.Interfaces.IDriverFinanceService
{
    public interface IDriverFinanceService
    {
        // ---- ledger posting (system) ----

        // Brings a completed trip's ledger entries in line with how it was actually
        // settled (cash kept by the captain vs paid online). Idempotent: safe to call
        // from every place a trip or its payment changes.
        Task SyncTripLedgerAsync(string tripId);

        // Called after any Payment row changes status. Credits captain settlements and
        // re-syncs the trip for trip payments.
        Task OnPaymentUpdatedAsync(string paymentId);

        // ---- gatekeeping ----
        Task<OnlineEligibilityDTO> CheckOnlineEligibilityAsync(string driverId, bool useCache = false);
        void InvalidateEligibility(string driverId);
        // After the balance or status changed: if the captain can no longer work, take
        // him offline and tell his app why.
        Task EnforceEligibilityAsync(string driverId);

        // ---- captain ----
        Task<decimal> GetBalanceAsync(string driverId);
        Task<Response<DriverFinanceSummaryDTO>> GetSummaryAsync(string driverId);
        Task<Response<PaginationPagedResponse<LedgerEntryDTO>>> GetLedgerAsync(string driverId, PaginationRequest pagination, string? type = null);
        Task<Response<string>> SetPayoutAccountAsync(string driverId, SetPayoutAccountDTO dto);
        Task<Response<SettlementStatusDTO>> GetSettlementStatusAsync(string driverId, string paymentId);

        // ---- admin ----
        Task<DriverFinanceSettingsDTO> GetSettingsAsync();
        Task<Response<DriverFinanceSettingsDTO>> UpdateSettingsAsync(DriverFinanceSettingsDTO dto, string actorUserId);
        Task<Response<FinanceOverviewDTO>> GetOverviewAsync();
        Task<Response<PaginationPagedResponse<AdminDriverFinanceRowDTO>>> GetDriversAsync(PaginationRequest pagination, string? search, string? filter);
        Task<Response<LedgerEntryDTO>> AddAdjustmentAsync(string driverId, AdjustmentRequestDTO dto, string actorUserId);
        Task<Response<LedgerEntryDTO>> RecordPayoutAsync(string driverId, PayoutRequestDTO dto, string? attachmentUrl, string actorUserId);
        Task<Response<PaginationPagedResponse<SettlementRowDTO>>> GetSettlementsAsync(PaginationRequest pagination, string? status);
        Task<Response<PaginationPagedResponse<AuditLogDTO>>> GetAuditLogAsync(PaginationRequest pagination, string? targetUserId);
        Task WriteAuditAsync(string actorUserId, string action, string? targetUserId, string? details);
    }
}
