using Masafet_Elseka.Application.Common.Pagination;
using Masafet_Elseka.Application.DTOs.DriverFinance;
using Masafet_Elseka.Application.Interfaces.IDriverFinanceService;
using Masafet_Elseka.Application.Interfaces.IPaymentService;
using Masafet_Elseka.Application.Interfaces.IPrivateFileStorage;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Infrastructure.Data;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace Masafet_Elseka.Presentation.Controllers
{
    // Captain finance: the captain's own account (me/...) and the dashboard's
    // finance management (admin/...). Every response is { isSuccess, message, data }.
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    [Route("api/[controller]")]
    [ApiController]
    public class DriverFinanceController : ControllerBase
    {
        private const string FinanceAdmins = "Admin, Accountant";
        private const long MaxReceiptBytes = 8 * 1024 * 1024;

        private readonly IDriverFinanceService _finance;
        private readonly IPaymentService _paymentService;
        private readonly IPrivateFileStorage _storage;
        private readonly Context _context;

        public DriverFinanceController(IDriverFinanceService finance, IPaymentService paymentService,
            IPrivateFileStorage storage, Context context)
        {
            _finance = finance;
            _paymentService = paymentService;
            _storage = storage;
            _context = context;
        }

        private string UserId => User.FindFirstValue(ClaimTypes.NameIdentifier)!;

        private IActionResult Reply<T>(Response<T> r) => r.IsSuccess
            ? StatusCode(r.StatusCode, new { isSuccess = true, message = r.Message, data = r.Data })
            : StatusCode(r.StatusCode, new { isSuccess = false, message = r.Message, errors = r.Errors });

        // ===================== Captain =====================

        [Authorize(Roles = "Driver")]
        [HttpGet("me/summary")]
        public async Task<IActionResult> MySummary() => Reply(await _finance.GetSummaryAsync(UserId));

        [Authorize(Roles = "Driver")]
        [HttpGet("me/ledger")]
        public async Task<IActionResult> MyLedger([FromQuery] PaginationRequest pagination, [FromQuery] string? type)
            => Reply(await _finance.GetLedgerAsync(UserId, pagination, type));

        [Authorize(Roles = "Driver")]
        [HttpGet("me/eligibility")]
        public async Task<IActionResult> MyEligibility()
            => Reply(Response<OnlineEligibilityDTO>.Success(await _finance.CheckOnlineEligibilityAsync(UserId), "", 200));

        [Authorize(Roles = "Driver")]
        [HttpPut("me/payout-account")]
        public async Task<IActionResult> SetPayoutAccount([FromBody] SetPayoutAccountDTO dto)
            => Reply(await _finance.SetPayoutAccountAsync(UserId, dto));

        // Starts a Paymob checkout for exactly what the captain owes.
        [Authorize(Roles = "Driver")]
        [HttpPost("me/settle")]
        public async Task<IActionResult> Settle() => Reply(await _paymentService.CreateDriverSettlementIntentAsync(UserId));

        // Polled by the app after checkout: reconciles with Paymob if still pending.
        [Authorize(Roles = "Driver")]
        [HttpGet("me/settle/{paymentId}")]
        public async Task<IActionResult> SettlementStatus(string paymentId)
        {
            await _paymentService.RefreshSettlementAsync(paymentId, UserId);
            return Reply(await _finance.GetSettlementStatusAsync(UserId, paymentId));
        }

        // Payout receipt: the captain who received it, or finance admins.
        [HttpGet("ledger/{entryId:long}/attachment")]
        public async Task<IActionResult> LedgerAttachment(long entryId)
        {
            var entry = await _context.DriverLedgerEntries.IgnoreQueryFilters().AsNoTracking()
                .FirstOrDefaultAsync(e => e.Id == entryId);
            if (entry?.AttachmentUrl == null) return NotFound(new { isSuccess = false, message = "لا يوجد إيصال" });

            var isFinanceAdmin = User.IsInRole("Admin") || User.IsInRole("Accountant");
            if (!isFinanceAdmin && entry.DriverId != UserId) return Forbid();

            var bytes = await _storage.ReadAsync(entry.AttachmentUrl);
            if (bytes == null) return NotFound(new { isSuccess = false, message = "ملف الإيصال غير موجود" });
            var ext = Path.GetExtension(entry.AttachmentUrl).ToLowerInvariant();
            var contentType = ext switch { ".png" => "image/png", ".webp" => "image/webp", ".pdf" => "application/pdf", _ => "image/jpeg" };
            return File(bytes, contentType);
        }

        // ===================== Admin =====================

        [Authorize(Roles = FinanceAdmins)]
        [HttpGet("admin/settings")]
        public async Task<IActionResult> GetSettings()
            => Reply(Response<DriverFinanceSettingsDTO>.Success(await _finance.GetSettingsAsync(), "", 200));

        [Authorize(Roles = FinanceAdmins)]
        [HttpPut("admin/settings")]
        public async Task<IActionResult> UpdateSettings([FromBody] DriverFinanceSettingsDTO dto)
            => Reply(await _finance.UpdateSettingsAsync(dto, UserId));

        [Authorize(Roles = FinanceAdmins)]
        [HttpGet("admin/overview")]
        public async Task<IActionResult> Overview() => Reply(await _finance.GetOverviewAsync());

        // filter: locked | near | owes | owed (optional)
        [Authorize(Roles = FinanceAdmins)]
        [HttpGet("admin/drivers")]
        public async Task<IActionResult> Drivers([FromQuery] PaginationRequest pagination, [FromQuery] string? search, [FromQuery] string? filter)
            => Reply(await _finance.GetDriversAsync(pagination, search, filter));

        [Authorize(Roles = FinanceAdmins)]
        [HttpGet("admin/drivers/{driverId}/summary")]
        public async Task<IActionResult> DriverSummary(string driverId) => Reply(await _finance.GetSummaryAsync(driverId));

        [Authorize(Roles = FinanceAdmins)]
        [HttpGet("admin/drivers/{driverId}/ledger")]
        public async Task<IActionResult> DriverLedger(string driverId, [FromQuery] PaginationRequest pagination, [FromQuery] string? type)
            => Reply(await _finance.GetLedgerAsync(driverId, pagination, type));

        [Authorize(Roles = FinanceAdmins)]
        [HttpPost("admin/drivers/{driverId}/adjustments")]
        public async Task<IActionResult> AddAdjustment(string driverId, [FromBody] AdjustmentRequestDTO dto)
            => Reply(await _finance.AddAdjustmentAsync(driverId, dto, UserId));

        // multipart/form-data: amount, reference, note?, receipt? (image or pdf)
        [Authorize(Roles = FinanceAdmins)]
        [HttpPost("admin/drivers/{driverId}/payouts")]
        [RequestSizeLimit(MaxReceiptBytes + 64 * 1024)]
        public async Task<IActionResult> RecordPayout(string driverId, [FromForm] PayoutRequestDTO dto, IFormFile? receipt)
        {
            string? receiptPath = null;
            if (receipt != null && receipt.Length > 0)
            {
                if (receipt.Length > MaxReceiptBytes)
                    return BadRequest(new { isSuccess = false, message = "حجم الإيصال كبير، الحد الأقصى 8 ميجا" });
                var ext = Path.GetExtension(receipt.FileName).ToLowerInvariant();
                if (ext is not (".jpg" or ".jpeg" or ".png" or ".webp" or ".pdf"))
                    return BadRequest(new { isSuccess = false, message = "الإيصال لازم يكون صورة أو PDF" });
                await using var stream = receipt.OpenReadStream();
                receiptPath = await _storage.SaveAsync(stream, $"payout-receipts/{driverId}", ext == ".jpeg" ? ".jpg" : ext);
            }

            var result = await _finance.RecordPayoutAsync(driverId, dto, receiptPath, UserId);
            if (!result.IsSuccess && receiptPath != null) _storage.Delete(receiptPath);
            return Reply(result);
        }

        // status: Pending | Paid | Failed (optional)
        [Authorize(Roles = FinanceAdmins)]
        [HttpGet("admin/settlements")]
        public async Task<IActionResult> Settlements([FromQuery] PaginationRequest pagination, [FromQuery] string? status)
            => Reply(await _finance.GetSettlementsAsync(pagination, status));

        [Authorize(Roles = "Admin, Accountant, Dispatcher")]
        [HttpGet("admin/audit")]
        public async Task<IActionResult> Audit([FromQuery] PaginationRequest pagination, [FromQuery] string? targetUserId)
            => Reply(await _finance.GetAuditLogAsync(pagination, targetUserId));
    }
}
