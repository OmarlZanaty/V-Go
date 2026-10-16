using System.Security.Claims;
using Masafet_Elseka.Application.DTOs.Promotions;
using Masafet_Elseka.Application.Interfaces.IPromotionService;
using Masafet_Elseka.Application.Response;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace Masafet_Elseka.Presentation.Controllers
{
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    [Route("api/[controller]")]
    [ApiController]
    public class PromotionsController : ControllerBase
    {
        private readonly IPromotionService _promotions;

        public PromotionsController(IPromotionService promotions)
        {
            _promotions = promotions;
        }

        private string? UserId => User.FindFirstValue(ClaimTypes.NameIdentifier);

        private IActionResult Reply<T>(Response<T> response) => response.IsSuccess
            ? StatusCode(response.StatusCode, response.Data)
            : StatusCode(response.StatusCode, new { message = response.Message, errors = response.Errors });

        // ---- Rider ----

        // Offers the signed-in rider can use now.
        [HttpGet("mine")]
        public async Task<IActionResult> Mine()
        {
            if (string.IsNullOrEmpty(UserId)) return Unauthorized();
            return Ok(await _promotions.GetMineAsync(UserId));
        }

        [EnableRateLimiting("auth")]
        [HttpPost("redeem")]
        public async Task<IActionResult> Redeem([FromBody] RedeemPromotionDTO dto)
        {
            if (string.IsNullOrEmpty(UserId)) return Unauthorized();
            var result = await _promotions.RedeemCodeAsync(UserId, dto?.Code ?? "");
            return result.IsSuccess
                ? Ok(new { message = result.Message, promotion = result.Data })
                : StatusCode(result.StatusCode, new { message = result.Message });
        }

        // ---- Dashboard ----

        [Authorize(Roles = "Admin")]
        [HttpGet("admin")]
        public async Task<IActionResult> All() => Ok(await _promotions.GetAllAsync());

        [Authorize(Roles = "Admin")]
        [HttpPost("admin")]
        public async Task<IActionResult> Create([FromBody] SavePromotionDTO dto)
            => Reply(await _promotions.CreateAsync(dto));

        [Authorize(Roles = "Admin")]
        [HttpPut("admin/{id:int}")]
        public async Task<IActionResult> Update(int id, [FromBody] SavePromotionDTO dto)
            => Reply(await _promotions.UpdateAsync(id, dto));

        [Authorize(Roles = "Admin")]
        [HttpPut("admin/{id:int}/active")]
        public async Task<IActionResult> SetActive(int id, [FromQuery] bool value)
            => Reply(await _promotions.SetActiveAsync(id, value));

        [Authorize(Roles = "Admin")]
        [HttpDelete("admin/{id:int}")]
        public async Task<IActionResult> Delete(int id)
            => Reply(await _promotions.DeleteAsync(id));
    }
}
