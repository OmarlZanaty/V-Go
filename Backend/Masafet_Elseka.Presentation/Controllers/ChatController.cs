using Masafet_Elseka.Application.Interfaces.IChatService;
using Masafet_Elseka.Application.Interfaces.IMessageService;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace Masafet_Elseka.Presentation.Controllers
{
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    [Route("api/[controller]")]
    [ApiController]
    public class ChatController : ControllerBase
    {
        private readonly IChatService _chatService;

        public ChatController(IChatService chatService)
        {
            _chatService = chatService;
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
