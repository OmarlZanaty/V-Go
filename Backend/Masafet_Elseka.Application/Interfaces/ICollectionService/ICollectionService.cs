using Masafet_Elseka.Application.Common.Pagination;
using Masafet_Elseka.Application.DTOs.Collection;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;

namespace Masafet_Elseka.Application.Interfaces.ICollectionService
{
    // Daily captain collection by mobile-wallet transfer, confirmed by the receipt SMS
    // relayed from the company phone (V-Go Collector app).
    public interface ICollectionService
    {
        // ---- captain ----
        Task<Response<MyCollectionDTO>> GetMyCollectionAsync(string driverId);
        Task<Response<CollectionRequestDTO>> CreateRequestAsync(string driverId, CreateCollectionRequestDTO dto);
        Task<Response<CollectionRequestDTO>> CancelRequestAsync(string driverId, long requestId);

        // ---- collector phone ----
        Task<Response<CollectorPairResultDTO>> PairDeviceAsync(CollectorPairDTO dto);
        Task<CollectorDevice?> AuthenticateDeviceAsync(string? deviceKey);
        Task<CollectorConfigDTO> HeartbeatAsync(CollectorDevice device, CollectorHeartbeatDTO dto);
        Task<List<CollectorSmsResultDTO>> IngestSmsAsync(CollectorDevice device, CollectorSmsBatchDTO batch);

        // ---- admin ----
        Task<Response<CollectionOverviewDTO>> GetOverviewAsync();
        Task<Response<PaginationPagedResponse<AdminCollectionRequestDTO>>> GetRequestsAsync(PaginationRequest pagination, string? status, string? search);
        Task<Response<PaginationPagedResponse<WalletSmsDTO>>> GetSmsAsync(PaginationRequest pagination, string? status, string? kind, string? search);
        Task<Response<WalletSmsDTO>> AssignSmsAsync(long smsId, AssignSmsDTO dto, string actorUserId);
        Task<Response<WalletSmsDTO>> DismissSmsAsync(long smsId, ReviewNoteDTO dto, string actorUserId);
        Task<Response<AdminCollectionRequestDTO>> RejectRequestAsync(long requestId, ReviewNoteDTO dto, string actorUserId);
        Task<Response<string>> UnlockDriverAsync(string driverId, ReviewNoteDTO dto, string actorUserId);

        Task<Response<List<AdminWalletDTO>>> GetWalletsAsync();
        Task<Response<AdminWalletDTO>> SaveWalletAsync(int? walletId, WalletUpsertDTO dto, string actorUserId);

        Task<Response<List<CollectorDeviceDTO>>> GetDevicesAsync();
        Task<Response<CollectorDeviceDTO>> CreateDeviceAsync(CreateDeviceDTO dto, string actorUserId);
        Task<Response<CollectorDeviceDTO>> NewPairingCodeAsync(Guid deviceId, string actorUserId);
        Task<Response<CollectorDeviceDTO>> SetDeviceActiveAsync(Guid deviceId, bool active, string actorUserId);

        // ---- background ----
        // Called every minute: evening notice, last-hour reminder, deadline lock,
        // and expiry of stale requests.
        Task RunCycleAsync();
    }
}
