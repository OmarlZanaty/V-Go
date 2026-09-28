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
    }
}
