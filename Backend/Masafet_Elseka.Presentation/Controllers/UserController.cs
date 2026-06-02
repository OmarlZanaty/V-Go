using Masafet_Elseka.Application.Common.Pagination;
using Masafet_Elseka.Application.DTOs.User;
using Masafet_Elseka.Application.Interfaces.User;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace Masafet_Elseka.Presentation.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class UserController : ControllerBase
    {

        private readonly IUserService _userService;
        public UserController(IUserService userService)
        {
            _userService = userService;
        }

        [HttpGet("allUsers")]
        [Authorize(Roles = "Admin, Dispatcher, Accountant")]
        public async Task<IActionResult> GetAll(string role)
        {
            if (string.IsNullOrEmpty(role))
            {
                return BadRequest("الدور غير صحيح");
            }
            var result = await _userService.GetAllAsync(role);
            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, result.Data);
            }
            return StatusCode(result.StatusCode, new { message = result.Message });
        }

        [HttpGet("allDashboardUsers")]
        [Authorize(Roles = "Admin, Dispatcher, Accountant", AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
        public async Task<IActionResult> GetDashboardUsers([FromQuery] PaginationRequest pagination, string role, string? search, string? gender)
        {
            var result = await _userService.GetAllForDashboard(pagination, role, search, gender);
            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, result.Data);
            }
            return StatusCode(result.StatusCode, new { message = result.Message });
        }

        [HttpGet("user/{id}")]
        public async Task<IActionResult> GetById(string id)
        {
            if (string.IsNullOrEmpty(id))
            {
                return BadRequest("المعرف غير صحيح");
            }
            var result = await _userService.GetByIdAsync(id);
            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, result.Data);
            }
            return StatusCode(result.StatusCode, new { message = result.Message });
        }

        [HttpPost("remove")]
        [Authorize(Roles = "Admin, Dispatcher", AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
        public async Task<IActionResult> RemoveUsersBulk([FromBody] List<string> userIds)
        {
            if (userIds == null || !userIds.Any())
                return BadRequest(new { message = "لا يوجد مستخدمين للحذف" });

            var result = await _userService.RemoveUsersBulk(userIds);

            var response = new
            {
                message = result.Message,
                notFoundIds = result.Data?.NotFoundIds ?? new List<string>(),
                succeededIds = result.Data?.SucceededIds ?? new List<string>(),
            };


            return StatusCode(result.StatusCode, response);
        }


        [HttpPost("block")]
        [Authorize(Roles = "Admin, Dispatcher", AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
        public async Task<IActionResult> BlockUsers([FromBody] List<string> userIds)
        {
            if (userIds == null || !userIds.Any())
                return BadRequest(new { message = "لم يتم إرسال أي مستخدمين" });

            var result = await _userService.BlockUsers(userIds);

            var response = new
            {
                message = result.Message,
                notFoundIds = result.Data?.NotFoundIds ?? new List<string>(),
                succeededIds = result.Data?.SucceededIds ?? new List<string>(),
                
            };
            return StatusCode(result.StatusCode, response);
        }


        [HttpPost("unblock")]
        [Authorize(Roles = "Admin, Dispatcher", AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
        public async Task<IActionResult> UnBlockUsers([FromBody] List<string> userIds)
        {
            if (userIds == null || !userIds.Any())
                return BadRequest(new { message = "لم يتم إرسال أي مستخدمين" });

            var result = await _userService.UnblockUsers(userIds);

            var response = new
            {
                message = result.Message,
                notFoundIds = result.Data?.NotFoundIds ?? new List<string>(),
                succeededIds = result.Data?.SucceededIds ?? new List<string>(),
            };

            return StatusCode(result.StatusCode, response);
        }

        [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
        [HttpPut("updateUserForAdmin/{userId}")]
        public async Task<IActionResult> UpdateUserForAdminAsync(string userId,[FromForm] UpdateAllDTO model)
        {
            var result = await _userService.UpdateUserForAdminAsync(userId, model);
            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, new { Data=result.Data, Message=result.Message});
            }
            return StatusCode(result.StatusCode, result.Message);
        }

        [HttpPut("update/{userId}")]
        public async Task<IActionResult> UpdateAsync(string userId, [FromForm] UserUpdateDTO model)
        {
            var result = await _userService.UpdateAsync(userId, model);
            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, new { Data = result.Data, Message = result.Message });
            }
            return StatusCode(result.StatusCode, result.Message);
        }

        [Authorize(Roles = "Admin, Dispatcher", AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
        [HttpGet("usersNumber")]
        public async Task<IActionResult> GetUsersNumber(string role)
        {
            var result = await _userService.GetUsersNumber(role);
            if (result.IsSuccess && result.Data != 0)
            {
                return StatusCode(result.StatusCode, result.Data);
            }
            return StatusCode(result.StatusCode, result.Message);
        }
    }
}
