using Masafet_Elseka.Application.DTOs.Collection;
using Masafet_Elseka.Application.Interfaces.ICollectionService;
using Masafet_Elseka.Domain.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace Masafet_Elseka.Presentation.Controllers
{
    // API for the V-Go Collector app on the company phone that holds the wallet SIMs.
    // It pairs once with a dashboard code, then sends its device key in X-Device-Key.
    [AllowAnonymous]
    [Route("api/[controller]")]
    [ApiController]
    public class CollectorController : ControllerBase
    {
        private const string KeyHeader = "X-Device-Key";
        private readonly ICollectionService _collection;

        public CollectorController(ICollectionService collection) => _collection = collection;

        // Lets the app tell "this is a V-Go server" apart from a wrong address (404).
        [HttpGet("ping")]
        public IActionResult Ping() => Ok(new { isSuccess = true, service = "vgo-collector", time = DateTime.Now.ToEgyptTime() });

        [EnableRateLimiting("auth")]
        [HttpPost("pair")]
        public async Task<IActionResult> Pair([FromBody] CollectorPairDTO dto)
        {
            var r = await _collection.PairDeviceAsync(dto);
            return r.IsSuccess
                ? Ok(new { isSuccess = true, message = r.Message, data = r.Data })
                : StatusCode(r.StatusCode, new { isSuccess = false, message = r.Message });
        }

        private async Task<CollectorDevice?> DeviceAsync() =>
            await _collection.AuthenticateDeviceAsync(Request.Headers[KeyHeader].FirstOrDefault());

        private IActionResult Unpaired() => Unauthorized(new
        {
            isSuccess = false,
            code = "DEVICE_NOT_PAIRED",
            message = "الموبايل ده مش مربوط أو اتوقف من لوحة التحكم. اربطه تاني بكود جديد",
        });

        [HttpPost("heartbeat")]
        public async Task<IActionResult> Heartbeat([FromBody] CollectorHeartbeatDTO dto)
        {
            var device = await DeviceAsync();
            if (device == null) return Unpaired();
            return Ok(new { isSuccess = true, data = await _collection.HeartbeatAsync(device, dto) });
        }

        [HttpPost("sms")]
        [RequestSizeLimit(512 * 1024)]
        public async Task<IActionResult> Sms([FromBody] CollectorSmsBatchDTO batch)
        {
            var device = await DeviceAsync();
            if (device == null) return Unpaired();
            return Ok(new { isSuccess = true, data = await _collection.IngestSmsAsync(device, batch) });
        }
    }
}
