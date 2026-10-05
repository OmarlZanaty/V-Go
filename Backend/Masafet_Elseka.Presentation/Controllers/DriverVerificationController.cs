using Masafet_Elseka.Application.Common.Pagination;
using Masafet_Elseka.Application.DTOs.DriverVerification;
using Masafet_Elseka.Application.Interfaces.IDriverVerificationService;
using Masafet_Elseka.Application.Response;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace Masafet_Elseka.Presentation.Controllers
{
    // Captain verification (selfie, national ID both sides, driving + vehicle licence).
    // Every JSON response is { isSuccess, message, data }.
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    [Route("api/[controller]")]
    [ApiController]
    public class DriverVerificationController : ControllerBase
    {
        private const string Reviewers = "Admin, Dispatcher";
        private readonly IDriverVerificationService _verification;

        public DriverVerificationController(IDriverVerificationService verification)
        {
            _verification = verification;
        }

        private string UserId => User.FindFirstValue(ClaimTypes.NameIdentifier)!;

        private IActionResult Reply<T>(Response<T> r) => r.IsSuccess
            ? StatusCode(r.StatusCode, new { isSuccess = true, message = r.Message, data = r.Data })
            : StatusCode(r.StatusCode, new { isSuccess = false, message = r.Message, errors = r.Errors });

        // ===================== Captain =====================

        [Authorize(Roles = "Driver")]
        [HttpGet("me")]
        public async Task<IActionResult> Me() => Reply(await _verification.GetForDriverAsync(UserId));

        // multipart/form-data: type (Selfie | NationalIdFront | NationalIdBack | DriverLicense |
        // VehicleLicense), file (jpg/png/webp, max 8 MB), expiryDate (yyyy-MM-dd, licences only)
        [Authorize(Roles = "Driver")]
        [HttpPost("me/documents")]
        [RequestSizeLimit(9 * 1024 * 1024)]
        public async Task<IActionResult> Upload([FromForm] string type, IFormFile file, [FromForm] DateTime? expiryDate)
            => Reply(await _verification.UploadDocumentAsync(UserId, type, file, expiryDate));

        // ===================== Admin =====================

        // status: needsreview (default) | all | PendingDocuments | UnderReview | Approved | Rejected | Suspended
        [Authorize(Roles = Reviewers)]
        [HttpGet("admin/queue")]
        public async Task<IActionResult> Queue([FromQuery] PaginationRequest pagination, [FromQuery] string? status, [FromQuery] string? search)
            => Reply(await _verification.GetQueueAsync(pagination, status, search));

        [Authorize(Roles = Reviewers)]
        [HttpGet("admin/drivers/{driverId}")]
        public async Task<IActionResult> Driver(string driverId) => Reply(await _verification.GetForDriverAsync(driverId));

        // Streams a private document image (ID / licence). Never exposed publicly.
        [Authorize(Roles = Reviewers)]
        [HttpGet("admin/documents/{documentId}/file")]
        public async Task<IActionResult> DocumentFile(string documentId)
        {
            var result = await _verification.GetDocumentFileAsync(documentId);
            if (!result.IsSuccess) return Reply(result);
            Response.Headers.CacheControl = "private, no-store";
            return File(result.Data.Content, result.Data.ContentType);
        }

        [Authorize(Roles = Reviewers)]
        [HttpPost("admin/documents/{documentId}/review")]
        public async Task<IActionResult> Review(string documentId, [FromBody] ReviewDocumentDTO dto)
            => Reply(await _verification.ReviewDocumentAsync(documentId, dto, UserId));

        [Authorize(Roles = Reviewers)]
        [HttpPost("admin/drivers/{driverId}/decision")]
        public async Task<IActionResult> Decide(string driverId, [FromBody] VerificationDecisionDTO dto)
            => Reply(await _verification.DecideAsync(driverId, dto, UserId));
    }
}
