using Masafet_Elseka.Application.Common.Pagination;
using Masafet_Elseka.Application.DTOs.Driver;
using Masafet_Elseka.Application.DTOs.Pagination;
using Masafet_Elseka.Application.Interfaces.IDriverService;
using Masafet_Elseka.Application.Interfaces.IEmergencyService;
using Masafet_Elseka.Domain.Enums;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace Masafet_Elseka.Presentation.Controllers
{
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    [Route("api/[controller]")]
    [ApiController]
    public class DriverController : ControllerBase
    {
        private readonly IDriverService _driverService;
        private readonly IEmergencyService _emergencyService;

        public DriverController(IDriverService driverService, IEmergencyService emergencyService)
        {
            _driverService = driverService;
            _emergencyService = emergencyService;
        }

        [HttpGet("driver/{id}")]
        public async Task<IActionResult> GetById(string id)
        {
            var response = await _driverService.GetByIdAsync(id);
            if (response.IsSuccess)
            {
                return StatusCode(response.StatusCode, response.Data);
            }
            return StatusCode(response.StatusCode, response.Message);
        }

        [HttpGet("allDrivers")]
        public async Task<IActionResult> GetAllDrivers([FromQuery] PaginationRequest pagination, string? search, string? gender, ScooterType? scooterType = null, string? profitMethod = null)
        {
            var response = await _driverService.GetAll(pagination, search, gender, scooterType, profitMethod);
            if (response.IsSuccess)
            {
                return StatusCode(response.StatusCode, new { response.IsSuccess, response.Data, response.Message });
            }
            return StatusCode(response.StatusCode, new { response.IsSuccess, response.Errors, response.Message });
        }

        [HttpPut("updateDriverStatus")]
        public async Task<IActionResult> UpdateStatus([FromForm]  string id, bool isAvailable)
        {
            var response = await _driverService.UpdateAvailability(id, isAvailable);
            return StatusCode(response.StatusCode, response.Message);
        }

        [HttpGet("availableDrivers")]
        public async Task<IActionResult> GetAvailableDrivers()
        {
            var response = await _driverService.GetAvailableDrivers();
            if (response.IsSuccess)
            {
                return StatusCode(response.StatusCode, response.Data);
            }
            return StatusCode(response.StatusCode, response.Message);
        }

        [HttpGet("availableDriversFromCache")]
        public async Task<IActionResult> GetAvailableDriversFromCache(string? gender)
        {
            var response = await _driverService.GetAvailableDriversFromCache(gender);
            if (response.IsSuccess)
            {
                return StatusCode(response.StatusCode, response.Data);
            }
            return StatusCode(response.StatusCode, response.Message);
        }

        [HttpPost("SetDriverStatusToCache")]
        public async Task<IActionResult> SetDriverStatusToCache(DriverStatusDTO status)
        {
            await _driverService.SetDriverStatusToCache(status);
            return Ok();
        }

        [HttpPost("sendAlert")]
        public async Task<IActionResult> SendAlert(AlertDTO model)
        {
            var response = await _emergencyService.SendAlert(model);
            if (response.IsSuccess)
            {
                return StatusCode(response.StatusCode, response.Data);
            }
            return StatusCode(response.StatusCode, response.Message);
        }
    }
}
