using Masafet_Elseka.Application.Interfaces.Statistics;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authentication.JwtBearer;
namespace Masafet_Elseka.Presentation.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class StatisticsController : ControllerBase
    {
        private readonly IStatisticsService _statisticsService;
        public StatisticsController(IStatisticsService statisticsService)
        {
            _statisticsService = statisticsService;
        }

        [Authorize(Roles = "Admin", AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
        [HttpGet("numbersStatistics")]
        public async Task<IActionResult> GetAdminDashboardStatistics()
        {
            var response = await _statisticsService.GetAdminDashboardStatistics();
            if(response == null)
            {
                return NotFound(new { Message = "No statistics available." });
            }
            return Ok(response);
        }

        [Authorize(Roles = "Accountant", AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
        [HttpGet("GetAccountantStatistics")]
        public async Task<IActionResult> GetAccountantStatistics()
        {
            var response = await _statisticsService.GetAccountantStatistics();
            if (response.IsSuccess)
            {
                return StatusCode(response.StatusCode, new { Data = response.Data, Message = response.Message });
            }
            return StatusCode(response.StatusCode, new { response.Message });
        }

        [Authorize(Roles = "Admin", AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
        [HttpGet("webStatistics")]
        public async Task<IActionResult> GetAdminWebDashboardStatistics()
        {
            var response = await _statisticsService.GetAdminWebDashboardStatistics();
            if (response == null)
            {
                return NotFound(new { Message = "No statistics available." });
            }
            return Ok(response);
        }
    }
}
