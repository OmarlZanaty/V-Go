using Masafet_Elseka.Application.Common.Pagination;
using Masafet_Elseka.Application.DTOs.Trip;
using Masafet_Elseka.Application.Interfaces.IAccountantService;
using Masafet_Elseka.Application.Interfaces.ITripService;
using Masafet_Elseka.Application.Interfaces.Statistics;
using Masafet_Elseka.Domain.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace Masafet_Elseka.Presentation.Controllers
{
    [Authorize(Roles = "Client, Driver, Admin, Dispatcher, Accountant")]
    [Route("api/[controller]")]
    [ApiController]
    public class TripController : ControllerBase
    {
        private readonly ITripService _tripService;
        private readonly IAccountantService _accountantService;
        private readonly IStatisticsService _statisticsService;
        public TripController(ITripService tripService, IAccountantService accountantService, IStatisticsService statisticsService)
        {
            _tripService = tripService;
            _accountantService = accountantService;
            _statisticsService = statisticsService;
        }

        [HttpGet("GetAllTripsByStatus")]
        public async Task<IActionResult> GetAllTrips([FromQuery] TripStatus? status, [FromQuery] PaginationRequest pagination, CancellationToken ct = default)
        {
            var response = await _tripService.GetAll(pagination, status, ct);
            if (response.IsSuccess)
                return StatusCode(response.StatusCode, response.Data);
            return StatusCode(response.StatusCode, new { message = response.Message });
        }

        [HttpGet("allDashboardTrips")]
        public async Task<IActionResult> GetAllForDashboard([FromQuery] TripStatus? status, [FromQuery] PaginationRequest pagination, CancellationToken ct = default)
        {
            var response = await _tripService.GetAllForDashboard(pagination, status, ct);
            if (response.IsSuccess)
                return StatusCode(response.StatusCode, new { response.IsSuccess, response.Data, response.Message });
            return StatusCode(response.StatusCode, new { response.IsSuccess, response.Errors, response.Message });
        }

        [HttpGet("GetAllPendingTrips")]
        public async Task<IActionResult> GetPendingTrips()
        {
            var response = await _tripService.GetPendingTrips();
            if (response.IsSuccess)
            {
                return StatusCode(response.StatusCode, response.Data);
            }
            return StatusCode(response.StatusCode, response.Message);
        }
        [HttpGet("GetTripById/{id}")]
        public async Task<IActionResult> GetTripById(string id)
        {
            var response = await _tripService.GetById(id);
            if (response.IsSuccess)
            {
                return StatusCode(response.StatusCode, response.Data);
            }
            return StatusCode(response.StatusCode, response.Message);
        }

        [HttpGet("tripByUserId/{userId}")]
        public async Task<IActionResult> GetTripByUserId(string userId,[FromQuery] PaginationRequest pagination,CancellationToken ct)
        {
            var response = await _tripService.GetByUserId(userId, pagination, ct);

            if (response.IsSuccess)
                return StatusCode(response.StatusCode, response.Data);

            return StatusCode(response.StatusCode, new { message = response.Message });
        }


        [HttpGet("cuurentTrip")]
        public async Task<IActionResult> GetCurrentTrip(string userId, UserTripRole role)
        {
            var response = await _tripService.GetCurrentTrip(userId, role);
            if (response.IsSuccess)
            {
                return StatusCode(response.StatusCode, response.Data);
            }
            return StatusCode(response.StatusCode, response.Message);
        }

        [HttpGet("cuurentTrips")]
        public async Task<IActionResult> GetCurrentTrips(string userId)
        {
            var response = await _tripService.GetCurrentTrips(userId);
            if (response.IsSuccess)
            {
                return StatusCode(response.StatusCode, response.Data);
            }
            return StatusCode(response.StatusCode, response.Message);
        }

        [HttpGet("GetTripsFromCach")]
        public async Task<IActionResult> GetTripsFromCach()
        {
            var response = await _tripService.GetAllTripsFromCache();
            if (response != null && response.Count > 0)
            {
                return StatusCode(200, response);
            }
            return StatusCode(404, "لا توجد رحلات في الذاكرة المؤقتة");

        }
        
        [HttpPut("endtrip")]
        public async Task<IActionResult> EndTrip(string tripId)
        {
            var response = await _tripService.EndTrip(tripId);
            if (response.IsSuccess)
            {
                return StatusCode(response.StatusCode, response.Data);
            }
            return StatusCode(response.StatusCode, response.Message);
        }

        [HttpPost("addtrip")]
        public async Task<IActionResult> AddTrip(TripRequest request)
        {
            var response = await _tripService.AddTrip(request);
            if (response.IsSuccess)
            {
                return StatusCode(response.StatusCode, response.Data);
            }
            return StatusCode(response.StatusCode, response.Message);
        }

    }
}
