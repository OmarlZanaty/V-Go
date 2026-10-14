using Masafet_Elseka.Application.DTOs.FreeRides;
using Masafet_Elseka.Application.Interfaces.IFreeRidesService;
using Masafet_Elseka.Application.Response;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Masafet_Elseka.Presentation.Controllers
{
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    [Route("api/[controller]")]
    [ApiController]
    public class FreeRidesController : ControllerBase
    {
        private readonly IFreeRidesService _freeRidesService;

        public FreeRidesController(IFreeRidesService freeRidesService)
        {
            _freeRidesService = freeRidesService;
        }

        private IActionResult Reply<T>(Response<T> response) => response.IsSuccess
            ? StatusCode(response.StatusCode, response.Data)
            : StatusCode(response.StatusCode, new { message = response.Message, errors = response.Errors });

        [Authorize(Roles = "Admin")]
        [HttpGet("admin/settings")]
        public async Task<IActionResult> GetSettings()
            => Reply(await _freeRidesService.GetAdminSettingsAsync());

        [Authorize(Roles = "Admin")]
        [HttpPut("admin/settings")]
        public async Task<IActionResult> UpdateSettings([FromBody] UpdateFreeRidesSettingsDTO dto)
            => Reply(await _freeRidesService.UpdateAdminSettingsAsync(dto));
    }
}
