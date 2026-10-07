using Masafet_Elseka.Application.Common.Pagination;
using Masafet_Elseka.Application.DTOs.Collection;
using Masafet_Elseka.Application.Interfaces.ICollectionService;
using Masafet_Elseka.Application.Response;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace Masafet_Elseka.Presentation.Controllers
{
    // Daily captain collection by wallet transfer: the captain's side (me/...) and the
    // dashboard's review / wallets / collector phones (admin/...).
    // Every response is { isSuccess, message, data }.
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    [Route("api/[controller]")]
    [ApiController]
    public class CollectionController : ControllerBase
    {
        private const string FinanceAdmins = "Admin, Accountant";
        private readonly ICollectionService _collection;

        public CollectionController(ICollectionService collection) => _collection = collection;

        private string UserId => User.FindFirstValue(ClaimTypes.NameIdentifier)!;

        private IActionResult Reply<T>(Response<T> r) => r.IsSuccess
            ? StatusCode(r.StatusCode, new { isSuccess = true, message = r.Message, data = r.Data })
            : StatusCode(r.StatusCode, new { isSuccess = false, message = r.Message, errors = r.Errors });

        // ===================== Captain =====================

        [Authorize(Roles = "Driver")]
        [HttpGet("me")]
        public async Task<IActionResult> Mine() => Reply(await _collection.GetMyCollectionAsync(UserId));

        [Authorize(Roles = "Driver")]
        [HttpPost("me/requests")]
        public async Task<IActionResult> CreateRequest([FromBody] CreateCollectionRequestDTO dto)
            => Reply(await _collection.CreateRequestAsync(UserId, dto));

        [Authorize(Roles = "Driver")]
        [HttpDelete("me/requests/{requestId:long}")]
        public async Task<IActionResult> CancelRequest(long requestId)
            => Reply(await _collection.CancelRequestAsync(UserId, requestId));

        // ===================== Admin =====================

        [Authorize(Roles = FinanceAdmins)]
        [HttpGet("admin/overview")]
        public async Task<IActionResult> Overview() => Reply(await _collection.GetOverviewAsync());

        // status: Pending | Confirmed | NeedsReview | Rejected | Expired | Cancelled | review
        [Authorize(Roles = FinanceAdmins)]
        [HttpGet("admin/requests")]
        public async Task<IActionResult> Requests([FromQuery] PaginationRequest pagination, [FromQuery] string? status, [FromQuery] string? search)
            => Reply(await _collection.GetRequestsAsync(pagination, status, search));

        [Authorize(Roles = FinanceAdmins)]
        [HttpPost("admin/requests/{requestId:long}/reject")]
        public async Task<IActionResult> RejectRequest(long requestId, [FromBody] ReviewNoteDTO dto)
            => Reply(await _collection.RejectRequestAsync(requestId, dto, UserId));

        // status: Unclaimed | Matched | NeedsReview | Assigned | Dismissed | NotApplicable | open
        // kind: Incoming | Outgoing | Ignored | Unparsed
        [Authorize(Roles = FinanceAdmins)]
        [HttpGet("admin/sms")]
        public async Task<IActionResult> Sms([FromQuery] PaginationRequest pagination, [FromQuery] string? status, [FromQuery] string? kind, [FromQuery] string? search)
            => Reply(await _collection.GetSmsAsync(pagination, status, kind, search));

        [Authorize(Roles = FinanceAdmins)]
        [HttpPost("admin/sms/{smsId:long}/assign")]
        public async Task<IActionResult> AssignSms(long smsId, [FromBody] AssignSmsDTO dto)
            => Reply(await _collection.AssignSmsAsync(smsId, dto, UserId));

        [Authorize(Roles = FinanceAdmins)]
        [HttpPost("admin/sms/{smsId:long}/dismiss")]
        public async Task<IActionResult> DismissSms(long smsId, [FromBody] ReviewNoteDTO dto)
            => Reply(await _collection.DismissSmsAsync(smsId, dto, UserId));

        [Authorize(Roles = FinanceAdmins)]
        [HttpPost("admin/drivers/{driverId}/unlock")]
        public async Task<IActionResult> UnlockDriver(string driverId, [FromBody] ReviewNoteDTO dto)
            => Reply(await _collection.UnlockDriverAsync(driverId, dto, UserId));

        [Authorize(Roles = FinanceAdmins)]
        [HttpGet("admin/wallets")]
        public async Task<IActionResult> Wallets() => Reply(await _collection.GetWalletsAsync());

        [Authorize(Roles = FinanceAdmins)]
        [HttpPost("admin/wallets")]
        public async Task<IActionResult> AddWallet([FromBody] WalletUpsertDTO dto)
            => Reply(await _collection.SaveWalletAsync(null, dto, UserId));

        [Authorize(Roles = FinanceAdmins)]
        [HttpPut("admin/wallets/{walletId:int}")]
        public async Task<IActionResult> UpdateWallet(int walletId, [FromBody] WalletUpsertDTO dto)
            => Reply(await _collection.SaveWalletAsync(walletId, dto, UserId));

        [Authorize(Roles = FinanceAdmins)]
        [HttpGet("admin/devices")]
        public async Task<IActionResult> Devices() => Reply(await _collection.GetDevicesAsync());

        [Authorize(Roles = FinanceAdmins)]
        [HttpPost("admin/devices")]
        public async Task<IActionResult> AddDevice([FromBody] CreateDeviceDTO dto)
            => Reply(await _collection.CreateDeviceAsync(dto, UserId));

        [Authorize(Roles = FinanceAdmins)]
        [HttpPost("admin/devices/{deviceId:guid}/pairing-code")]
        public async Task<IActionResult> PairingCode(Guid deviceId)
            => Reply(await _collection.NewPairingCodeAsync(deviceId, UserId));

        [Authorize(Roles = FinanceAdmins)]
        [HttpPost("admin/devices/{deviceId:guid}/active/{active:bool}")]
        public async Task<IActionResult> SetDeviceActive(Guid deviceId, bool active)
            => Reply(await _collection.SetDeviceActiveAsync(deviceId, active, UserId));
    }
}
