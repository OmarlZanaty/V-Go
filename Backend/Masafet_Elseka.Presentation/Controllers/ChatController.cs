using Masafet_Elseka.Application.Interfaces.IChatService;
using Masafet_Elseka.Application.Interfaces.IMessageService;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace Masafet_Elseka.Presentation.Controllers
{
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    [Route("api/[controller]")]
    [ApiController]
    public class ChatController : ControllerBase
    {
        private readonly IChatService _chatService;
        private readonly ISupportInboxService _inbox;

        public ChatController(IChatService chatService, ISupportInboxService inbox)
        {
            _chatService = chatService;
            _inbox = inbox;
        }

        // ---- Dashboard support inbox (Admin, Dispatcher) ----
        private const string SupportStaff = "Admin, Dispatcher";

        [Authorize(Roles = SupportStaff)]
        [HttpGet("admin/support")]
        public async Task<IActionResult> SupportInbox([FromQuery] string status = "open", [FromQuery] string? search = null,
            [FromQuery] int page = 1, [FromQuery] int pageSize = 30, CancellationToken ct = default)
            => Ok(await _inbox.ListAsync(status, search, page, pageSize, ct));

        [Authorize(Roles = SupportStaff)]
        [HttpGet("admin/support/unread-count")]
        public async Task<IActionResult> SupportUnread(CancellationToken ct = default)
            => Ok(new { count = await _inbox.UnreadCountAsync(ct) });

        [Authorize(Roles = SupportStaff)]
        [HttpGet("admin/support/{chatId}/messages")]
        public async Task<IActionResult> SupportMessages(string chatId, [FromQuery] int skip = 0, [FromQuery] int take = 200, CancellationToken ct = default)
        {
            var r = await _inbox.MessagesAsync(chatId, skip, take, ct);
            return r.IsSuccess ? Ok(r.Data) : StatusCode(r.StatusCode, new { message = r.Message });
        }

        public class SupportReplyDTO { public string Content { get; set; } = string.Empty; }

        [Authorize(Roles = SupportStaff)]
        [HttpPost("admin/support/{chatId}/reply")]
        public async Task<IActionResult> SupportReply(string chatId, [FromBody] SupportReplyDTO body, CancellationToken ct = default)
        {
            var staffId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(staffId)) return Unauthorized();
            var r = await _inbox.ReplyAsync(chatId, staffId, body.Content, ct);
            return r.IsSuccess ? Ok(r.Data) : StatusCode(r.StatusCode, new { message = r.Message });
        }

        [Authorize(Roles = SupportStaff)]
        [HttpPut("admin/support/{chatId}/close")]
        public async Task<IActionResult> SupportClose(string chatId, CancellationToken ct = default)
        {
            var r = await _inbox.SetOpenAsync(chatId, false, ct);
            return StatusCode(r.StatusCode, new { message = r.Message });
        }

        [Authorize(Roles = SupportStaff)]
        [HttpPut("admin/support/{chatId}/reopen")]
        public async Task<IActionResult> SupportReopen(string chatId, CancellationToken ct = default)
        {
            var r = await _inbox.SetOpenAsync(chatId, true, ct);
            return StatusCode(r.StatusCode, new { message = r.Message });
        }

        [HttpGet("allDispatcherSupportChats")]
        public async Task<IActionResult> GetSupportChatsByDispatcherId([FromQuery] string dispatcherId, bool isOpen = true)
        {
            var response = await _chatService.GetSupportChatsByDispatcherIdAsync(dispatcherId, isOpen);
            if (!response.IsSuccess)
            {
                return StatusCode(response.StatusCode, response.Message);
            }
            return StatusCode(response.StatusCode, response.Data);
        }

        [HttpGet("supportChat")]
        public async Task<IActionResult> GetSupportChatById([FromQuery] string chatId)
        {
            if (string.IsNullOrEmpty(chatId))
            {
                return BadRequest("Chat Id is required.");
            }

            var response = await _chatService.GetByIdAsync(chatId);
            if (!response.IsSuccess)
            {
                return StatusCode(response.StatusCode, response.Message);
            }
            return Ok(response.Data);
        }

        [HttpPost("createSupportChat")]
        public async Task<IActionResult> CreateSupportChatAsync([FromQuery] string clientId)
        {
            if (string.IsNullOrEmpty(clientId))
            {
                return BadRequest("Client ID is required.");
            }
            var response = await _chatService.CreateSupportChatAsync(clientId);
            if (!response.IsSuccess)
            {
                return StatusCode(response.StatusCode, response.Message);
            }
            return Ok(response.Data);
        }

        [HttpPut("closeSupportChat")]
        public async Task<IActionResult> CloseChat([FromQuery] string chatId)
        {
            if (string.IsNullOrEmpty(chatId))
            {
                return BadRequest("Chat Id is required.");
            }
            var response = await _chatService.CloseChatAsync(chatId);
            if (!response.IsSuccess)
            {
                return StatusCode(response.StatusCode, response.Message);
            }
            return Ok(response.Data);
        }
    }
}
