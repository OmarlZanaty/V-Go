using Masafet_Elseka.Infrastructure.Services.DispatchSettings;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Masafet_Elseka.Presentation.Controllers
{
    // Admin dashboard: how far (km) from the pickup captains still get trip offers.
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme, Roles = "Admin")]
    [Route("api/[controller]")]
    [ApiController]
    public class DispatchSettingsController(IDispatchSettingsService dispatch) : ControllerBase
    {
        public record DispatchSettingsDTO(double RadiusKm);

        [HttpGet]
        public async Task<IActionResult> Get(CancellationToken ct)
            => Ok(Envelope(await dispatch.GetRadiusKmAsync(ct)));

        [HttpPut]
        public async Task<IActionResult> Update([FromBody] DispatchSettingsDTO dto, CancellationToken ct)
        {
            if (!DispatchSettingsService.IsValid(dto.RadiusKm))
                return BadRequest(new
                {
                    isSuccess = false,
                    message = $"النطاق لازم يكون بين {DispatchSettingsService.MinRadiusKm} و {DispatchSettingsService.MaxRadiusKm} كم",
                });
            await dispatch.SetRadiusKmAsync(dto.RadiusKm, ct);
            return Ok(Envelope(dto.RadiusKm));
        }

        private static object Envelope(double radiusKm) => new
        {
            isSuccess = true,
            message = "",
            data = new
            {
                radiusKm,
                minRadiusKm = DispatchSettingsService.MinRadiusKm,
                maxRadiusKm = DispatchSettingsService.MaxRadiusKm,
            },
        };
    }
}
