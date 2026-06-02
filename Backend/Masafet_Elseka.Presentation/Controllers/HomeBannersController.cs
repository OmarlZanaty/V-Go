using Masafet_Elseka.Application.Interfaces.HomeBanner;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace Masafet_Elseka.Presentation.Controllers
{
    [Authorize(Roles = "Admin, Dispatcher", AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    [Route("api/[controller]")]
    [ApiController]
    public class HomeBannersController : ControllerBase
    {
        private readonly IHomeBannerService _homeBannerService;
        public HomeBannersController(IHomeBannerService homeBannerService)
        {
            _homeBannerService = homeBannerService;
        }

        [HttpGet("getBanners")]
        public async Task<IActionResult> GetBanners()
        {
            var response = await _homeBannerService.GetHomeBannersAsync();
            if (response.IsSuccess)
            {
                return StatusCode(response.StatusCode, response.Data);
            }
            return StatusCode(response.StatusCode, response.Message);
        }

        [HttpPost("addBanners")]
        public async Task<IActionResult> AddBanners([FromForm] List<IFormFile> banners)
        {
            var response = await _homeBannerService.AddBannersAsync(banners);
            if (response.IsSuccess)
            {
                return StatusCode(response.StatusCode, response.Message);
            }
            return StatusCode(response.StatusCode, response.Message);
        }

        [HttpDelete("removeBanners")]
        public async Task<IActionResult> RemoveBanners([FromBody] List<string> bannersUrls)
        {
            var response = await _homeBannerService.RemoveBannersAsync(bannersUrls);
            if (response.IsSuccess)
            {
                return StatusCode(response.StatusCode, response.Message);
            }
            return StatusCode(response.StatusCode, response.Message);
        }
    }
}
