using Masafet_Elseka.Application.DTOs;
using Masafet_Elseka.Application.DTOs.Rating;
using Masafet_Elseka.Application.Interfaces.IRatingService;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace Masafet_Elseka.Presentation.Controllers
{
    [Authorize(Roles = "Client, Driver, Admin, Dispatcher, Accountant", AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    [Route("api/[controller]")]
    [ApiController]
    public class RateController : ControllerBase
    {
        private readonly IRatingService _ratingService;

        public RateController(IRatingService ratingService)
        {
            _ratingService = ratingService;
        }

        [HttpPost("addRate")]
        public async Task<IActionResult> AddRate([FromForm] RatingDTO rate)
        {
            var result = await _ratingService.AddRateAsync(rate);

            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, result.Data);
            }
            return StatusCode(result.StatusCode, result.Message);
        }

        [HttpGet("userRates/{userId}")]
        public async Task<IActionResult> GetUserRates(string userId)
        {
            var result = await _ratingService.GetUserRates(userId);

            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, result.Data);
            }
            return StatusCode(result.StatusCode, result.Message);
        }
    }
}
