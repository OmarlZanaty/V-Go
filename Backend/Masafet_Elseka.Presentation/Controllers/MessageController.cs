using Masafet_Elseka.Application.Interfaces.IMessageService;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace Masafet_Elseka.Presentation.Controllers
{
    [Authorize(Roles = "Client, Driver, Admin, Dispatcher", AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    [Route("api/[controller]")]
    [ApiController]
    public class MessageController : ControllerBase
    {
        private readonly IMessageService _messageService;

        public MessageController(IMessageService messageService)
        {
            _messageService = messageService;
        }

        [HttpPost("sendSupportMessage")]
        public async Task<IActionResult> SendSupportMessageAsync([FromQuery] string? chatId, [FromQuery] string senderId, [FromQuery] string content)
        {
            if (string.IsNullOrEmpty(senderId) || string.IsNullOrEmpty(content))
            {
                return BadRequest("Chat ID, Sender ID, and Content are required.");
            }
            var response = await _messageService.SendSupportMessageAsync(chatId, senderId, content);
            if (!response.IsSuccess)
            {
                return StatusCode(response.StatusCode, response.Message);
            }
            return Ok(response.Data);
        }

        [HttpGet("supportChatMessages")]
        public async Task<IActionResult> GetSupportChatMessages([FromQuery] string? chatId, string userId, int skip = 0, int take = 30)
        {
            if (string.IsNullOrEmpty(userId))
            {
                return BadRequest("User ID is required.");
            }
            var response = await _messageService.GetSupportChatMessagesAsync(chatId, userId, skip, take);
            if (!response.IsSuccess)
            {
                return StatusCode(response.StatusCode, response.Message);
            }
            return StatusCode(response.StatusCode, response.Data);
        }
       
    }
}
