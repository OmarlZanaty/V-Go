using System.ComponentModel.DataAnnotations;

namespace Masafet_Elseka.Application.DTOs.Beta
{
    public class BetaEnrollRequest
    {
        // Validate the chosen identity in the service: a supplied token takes precedence.
        public string? Email { get; set; }
        [MaxLength(16000)] public string? IdToken { get; set; }
        [MaxLength(40)] public string? Source { get; set; }
        [MaxLength(40)] public string? App { get; set; }
    }

    public record BetaEnrollResponse(bool PlaySynced, bool Delayed, string Status,
        bool AlreadyEnrolled, string PlayUrl, string DownloadUrl);
    public record BetaEnrollStatus(bool Registered, bool Synced, bool Rejected, bool Delayed);
    public record BetaPendingTester(string Id, string Email);
    public record BetaPendingResponse(IReadOnlyList<BetaPendingTester> Testers);
    public record BetaDaemonHealth(bool Online, DateTimeOffset? LastPoll);
    public record BetaStatusResponse(int Invited, int OptedIn, int Installed, int Dropped,
        int Synced, int Target, bool DaemonOnline, DateTimeOffset? LastPoll);
    public record BetaTesterDTO(string Id, string Email, string? GoogleSub, string Source,
        string Status, bool PlaySynced, string? PlayError, int SyncAttempts,
        DateTime EnrolledAt, DateTime? LastCheckedAt, DateTime? RemindedAt);
    public record BetaTestersPage(IReadOnlyList<BetaTesterDTO> Testers, int Total, int Page, int PageSize);

    public class BetaSyncDoneRequest
    {
        [Required, MinLength(1), MaxLength(100)]
        public string[] Ids { get; set; } = [];
    }

    public class BetaSyncFailedRequest
    {
        [Required, MaxLength(32)] public string Id { get; set; } = string.Empty;
        [MaxLength(200)] public string? Reason { get; set; }
        // Current daemon distinguishes a Play refusal from an automation failure.
        public bool? Refused { get; set; }
    }

    public class BetaSetStatusRequest
    {
        [Required, RegularExpression("^(invited|opted_in|installed|dropped)$")]
        public string Status { get; set; } = string.Empty;
    }

    public class BetaRequestException(int statusCode, string message) : Exception(message)
    {
        public int StatusCode { get; } = statusCode;
    }

    public record BetaGoogleIdentity(string Email, string Subject);
}
