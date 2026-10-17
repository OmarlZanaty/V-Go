using Masafet_Elseka.Application.DTOs.Beta;
using Masafet_Elseka.Application.Interfaces.IBetaService;
using Masafet_Elseka.Presentation.Filters;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace Masafet_Elseka.Presentation.Controllers
{
    [ApiController]
    [Route("api/beta")]
    [BetaExceptionFilter]
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme, Roles = "Admin")]
    public class BetaController(IBetaService beta) : ControllerBase
    {
        [AllowAnonymous, EnableRateLimiting("beta-enroll")]
        [HttpPost("enroll")]
        public async Task<IActionResult> Enroll(BetaEnrollRequest request, CancellationToken ct)
            => Ok(await beta.EnrollAsync(request, ct));

        [AllowAnonymous]
        [HttpGet("enroll/status")]
        public async Task<IActionResult> EnrollStatus([FromQuery] string email, CancellationToken ct)
            => Ok(await beta.EnrollStatusAsync(email, ct));

        [AllowAnonymous, BetaSyncKey]
        [HttpGet("sync/pending")]
        public async Task<IActionResult> Pending(CancellationToken ct) => Ok(await beta.PendingAsync(ct));

        [AllowAnonymous, BetaSyncKey]
        [HttpPost("sync/done")]
        public async Task<IActionResult> Done(BetaSyncDoneRequest request, CancellationToken ct)
            => Ok(new { updated = await beta.SyncDoneAsync(request.Ids, ct) });

        [AllowAnonymous, BetaSyncKey]
        [HttpPost("sync/failed")]
        public async Task<IActionResult> Failed(BetaSyncFailedRequest request, CancellationToken ct)
            => await beta.SyncFailedAsync(request, ct) ? Ok(new { ok = true }) : NotFound();

        [HttpGet("status")]
        public async Task<IActionResult> Status(CancellationToken ct) => Ok(await beta.StatusAsync(ct));

        [HttpGet("testers")]
        public async Task<IActionResult> Testers(CancellationToken ct, [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
            => Ok(await beta.TestersAsync(page, pageSize, ct));

        [HttpPatch("testers/{id}")]
        public async Task<IActionResult> SetStatus(string id, BetaSetStatusRequest request, CancellationToken ct)
            => await beta.SetStatusAsync(id, request.Status, ct) ? Ok(new { ok = true }) : NotFound();

        [HttpPost("testers/{id}/retry-sync")]
        public async Task<IActionResult> RetrySync(string id, CancellationToken ct)
            => await beta.RetrySyncAsync(id, ct) ? Ok(new { playSynced = false }) : NotFound();
    }
}
