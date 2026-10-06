using Masafet_Elseka.Application.DTOs.HomeBanner;
using Masafet_Elseka.Application.Interfaces.HomeBanner;
using Masafet_Elseka.Application.Response;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace Masafet_Elseka.Presentation.Controllers
{
    // Home carousel ad slots. The app reads `active` (no login needed, so the home
    // screen loads even before auth); the dashboard manages everything under admin.
    // JSON responses are { isSuccess, message, data }.
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    [Route("api/[controller]")]
    [ApiController]
    public class HomeBannersController : ControllerBase
    {
        private const string Managers = "Admin, Dispatcher";
        private readonly IHomeBannerService _banners;

        public HomeBannersController(IHomeBannerService banners)
        {
            _banners = banners;
        }

        private string UserId => User.FindFirstValue(ClaimTypes.NameIdentifier)!;

        private IActionResult Reply<T>(Response<T> r) => r.IsSuccess
            ? StatusCode(r.StatusCode, new { isSuccess = true, message = r.Message, data = r.Data })
            : StatusCode(r.StatusCode, new { isSuccess = false, message = r.Message, errors = r.Errors });

        [AllowAnonymous]
        [HttpGet("active")]
        public async Task<IActionResult> Active() => Reply(await _banners.GetActiveAsync());

        [AllowAnonymous]
        [HttpPost("{id:int}/click")]
        public async Task<IActionResult> Click(int id)
        {
            await _banners.RecordClickAsync(id);
            return NoContent();
        }

        [Authorize(Roles = Managers)]
        [HttpGet("admin")]
        public async Task<IActionResult> All() => Reply(await _banners.GetAllAsync());

        // multipart/form-data: image (required), title?, linkUrl?, isActive, startsAt?, endsAt?
        [Authorize(Roles = Managers)]
        [HttpPost("admin")]
        [RequestSizeLimit(6 * 1024 * 1024)]
        public async Task<IActionResult> Create([FromForm] SaveBannerDTO dto, IFormFile? image)
            => Reply(await _banners.CreateAsync(dto, image, UserId));

        // multipart/form-data: same fields; image only when replacing it.
        [Authorize(Roles = Managers)]
        [HttpPut("admin/{id:int}")]
        [RequestSizeLimit(6 * 1024 * 1024)]
        public async Task<IActionResult> Update(int id, [FromForm] SaveBannerDTO dto, IFormFile? image)
            => Reply(await _banners.UpdateAsync(id, dto, image, UserId));

        [Authorize(Roles = Managers)]
        [HttpDelete("admin/{id:int}")]
        public async Task<IActionResult> Delete(int id) => Reply(await _banners.DeleteAsync(id, UserId));

        // Body: [3, 1, 2] — every banner id, in the new order.
        [Authorize(Roles = Managers)]
        [HttpPut("admin/order")]
        public async Task<IActionResult> Reorder([FromBody] List<int> orderedIds)
            => Reply(await _banners.ReorderAsync(orderedIds, UserId));
    }
}
