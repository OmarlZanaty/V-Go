using Masafet_Elseka.Application.Common.Pagination;
using Masafet_Elseka.Application.DTOs.DriverVerification;
using Masafet_Elseka.Application.Response;
using Microsoft.AspNetCore.Http;

namespace Masafet_Elseka.Application.Interfaces.IDriverVerificationService
{
    public interface IDriverVerificationService
    {
        // ---- captain ----
        Task<Response<DriverVerificationDTO>> GetForDriverAsync(string driverId);
        Task<Response<DriverDocumentDTO>> UploadDocumentAsync(string driverId, string type, IFormFile file, DateTime? expiryDate);

        // ---- admin ----
        Task<Response<PaginationPagedResponse<VerificationQueueItemDTO>>> GetQueueAsync(PaginationRequest pagination, string? status, string? search);
        Task<Response<DocumentFileDTO>> GetDocumentFileAsync(string documentId);
        Task<Response<DriverDocumentDTO>> ReviewDocumentAsync(string documentId, ReviewDocumentDTO dto, string actorUserId);
        Task<Response<DriverVerificationDTO>> DecideAsync(string driverId, VerificationDecisionDTO dto, string actorUserId);
    }
}
