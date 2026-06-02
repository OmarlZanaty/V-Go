using Masafet_Elseka.Application.Common.Pagination;
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
