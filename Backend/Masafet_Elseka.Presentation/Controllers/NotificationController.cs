using Masafet_Elseka.Application.Common.Pagination;
using Masafet_Elseka.Application.DTOs.Notification;
using Masafet_Elseka.Application.Interfaces.INotificationService;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace Masafet_Elseka.Presentation.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize(Roles = "Client, Driver, Admin, Dispatcher, Accountant", AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    public class NotificationController : ControllerBase
    {
        private readonly INotificationService _notificationService;
        public NotificationController(INotificationService notificationService)
        {
            _notificationService = notificationService;
        }

        /// <summary>
        /// (Re)register this device's FCM token for the signed-in user. The apps
        /// call it on every launch and whenever Firebase rotates the token; until
        /// this existed a token was only ever sent at login, so a rotated token
        /// meant silent pushes until the next sign-in.
        /// </summary>
        [HttpPost("RegisterDevice")]
        public async Task<IActionResult> RegisterDevice([FromBody] RegisterDeviceDTO model, CancellationToken ct)
        {
            if (string.IsNullOrWhiteSpace(model.FCMToken))
                return BadRequest(new { message = "FCMToken is required" });

            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            await _notificationService.RegisterDeviceAsync(userId!, model.FCMToken, model.DeviceType ?? "Android", null, ct);
            return Ok(new { success = true });
        }

        [HttpGet("GetAll")]
        public async Task<IActionResult> GetAllForUser([FromQuery] PaginationRequest pagination,CancellationToken ct)

        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var result=await _notificationService.GetAllForUser(userId!, pagination, ct);
            if (!result.IsSuccess || !result.Data.Data.Any())
            {
                return StatusCode(result.StatusCode, result.Data);
            }
            return StatusCode(result.StatusCode, result.Data);
        }

        // Dashboard «الإشعارات» page.
        [Authorize(Roles = "Admin", AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
        [HttpPost("sendToAll")]
        public Task<IActionResult> SendToAll([FromBody] BroadcastNotificationDTO model, CancellationToken ct)
            => Broadcast(model, null, ct);

        [Authorize(Roles = "Admin", AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
        [HttpPost("sendToRole")]
        public Task<IActionResult> SendToRole([FromBody] BroadcastNotificationDTO model, CancellationToken ct)
        {
            if (model.Role is not ("Client" or "Driver"))
                return Task.FromResult<IActionResult>(BadRequest(new { message = "الفئة لازم تكون Client أو Driver" }));
            return Broadcast(model, model.Role, ct);
        }

        [Authorize(Roles = "Admin", AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
        [HttpGet("broadcastStats")]
        public async Task<IActionResult> BroadcastStats([FromQuery] string? role, CancellationToken ct)
        {
            var result = await _notificationService.BroadcastStatsAsync(role, ct);
            return StatusCode(result.StatusCode, new { message = result.Message, data = result.Data });
        }

        private async Task<IActionResult> Broadcast(BroadcastNotificationDTO model, string? role, CancellationToken ct)
        {
            if (model.Limit is <= 0)
                return BadRequest(new { message = "عدد المستلمين لازم يكون أكبر من صفر" });
            var result = await _notificationService.BroadcastAsync(model.Title, model.Body, role, model.Limit, model.OnlyNew ?? true, ct);
            return StatusCode(result.StatusCode, new { message = result.Message, data = result.Data });
        }
    }

    public class BroadcastNotificationDTO
    {
        public string Title { get; set; } = string.Empty;
        public string Body { get; set; } = string.Empty;
        public string? Role { get; set; }
        // Optional: send to this many users only, picked at random.
        public int? Limit { get; set; }
        // With Limit: pick only among users never reached by a broadcast (default true).
        public bool? OnlyNew { get; set; }
    }
}
