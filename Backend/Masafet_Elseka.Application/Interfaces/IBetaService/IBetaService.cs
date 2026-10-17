using Masafet_Elseka.Application.DTOs.Beta;

namespace Masafet_Elseka.Application.Interfaces.IBetaService
{
    public interface IBetaService
    {
        Task<BetaEnrollResponse> EnrollAsync(BetaEnrollRequest request, CancellationToken ct = default);
        Task<BetaEnrollStatus> EnrollStatusAsync(string email, CancellationToken ct = default);
        Task<BetaPendingResponse> PendingAsync(CancellationToken ct = default);
        Task<int> SyncDoneAsync(string[] ids, CancellationToken ct = default);
        Task<bool> SyncFailedAsync(BetaSyncFailedRequest request, CancellationToken ct = default);
        Task<BetaStatusResponse> StatusAsync(CancellationToken ct = default);
        Task<BetaTestersPage> TestersAsync(int page, int pageSize, CancellationToken ct = default);
        Task<bool> SetStatusAsync(string id, string status, CancellationToken ct = default);
        Task<bool> RetrySyncAsync(string id, CancellationToken ct = default);
        Task<BetaDaemonHealth> DaemonHealthAsync(CancellationToken ct = default);
    }

    public interface IBetaGoogleTokenVerifier
    {
        Task<BetaGoogleIdentity> VerifyAsync(string token, CancellationToken ct = default);
    }
}
