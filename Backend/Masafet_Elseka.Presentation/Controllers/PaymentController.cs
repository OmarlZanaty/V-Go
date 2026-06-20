using Masafet_Elseka.Application.DTOs.Payment;
using Masafet_Elseka.Application.DTOs.Payment.PayMob;
using Masafet_Elseka.Application.Interfaces.IPaymentService;
using Masafet_Elseka.Application.Response;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.WebUtilities;
using System.Linq;
using System.Security.Claims;
using System.Text.Json;

namespace Masafet_Elseka.Presentation.Controllers
{
    [Authorize(Roles = "Client, Driver, Admin, Dispatcher, Accountant", AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    [Route("api/[controller]")]
    [ApiController]
    public class PaymentController : ControllerBase
    {
        private readonly IPaymentService _paymentService;

        public PaymentController(IPaymentService paymentService)
        {
            _paymentService = paymentService;
        }

        [HttpPost("createIntent")]
        public async Task<IActionResult> CreateIntent(PaymentRequestDTO request)
        {
            var response = await _paymentService.CreatePaymentIntentAsync(request);
            if(response.IsSuccess)
            {
                return StatusCode(response.StatusCode, response.Data);
            }
            return StatusCode(response.StatusCode, response.Message);
        }

        // Visa pre-authorization: client creates a hold intention. Returns the same
        // unified-checkout payload as createIntent, so the Flutter webview is unchanged.
        [Authorize(Roles = "Client", AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
        [HttpPost("initiate-preauth")]
        public async Task<IActionResult> InitiatePreAuth(PaymentRequestDTO request)
        {
            var response = await _paymentService.InitiatePreAuthAsync(request);
            if (response.IsSuccess)
            {
                return StatusCode(response.StatusCode, response.Data);
            }
            return StatusCode(response.StatusCode, response.Message);
        }

        // Capture the held amount on ride completion (driver/admin).
        [Authorize(Roles = "Driver, Admin", AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
        [HttpPost("capture/{tripId}")]
        public async Task<IActionResult> Capture(string tripId)
        {
            var response = await _paymentService.CaptureRidePaymentAsync(tripId);
            return StatusCode(response.StatusCode, response.IsSuccess ? (object)response.Data : response.Message);
        }

        // Void the held amount on cancellation (rider/admin).
        [Authorize(Roles = "Client, Admin", AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
        [HttpPost("void/{tripId}")]
        public async Task<IActionResult> Void(string tripId)
        {
            var response = await _paymentService.VoidRidePaymentAsync(tripId);
            return StatusCode(response.StatusCode, response.IsSuccess ? (object)response.Data : response.Message);
        }

        [AllowAnonymous]
        [HttpPost("webhook")]
        public async Task<IActionResult> HandleWebhook([FromBody] JsonElement payload, [FromQuery] string hmac)
        {
            // Paymob sends two webhook shapes: TRANSACTION (payment result) and
            // TOKEN (a saved card). Route by `type`. ALWAYS return 200 so Paymob
            // doesn't retry forever on our errors.
            try
            {
                var opts = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                var type = payload.TryGetProperty("type", out var t) ? t.GetString() : null;

                if (string.Equals(type, "TOKEN", System.StringComparison.OrdinalIgnoreCase)
                    && payload.TryGetProperty("obj", out var tokenObj))
                {
                    var dto = tokenObj.Deserialize<PaymobCardTokenDTO>(opts);
                    if (dto != null)
                        await _paymentService.HandleTokenWebhookAsync(dto, hmac);
                }
                else
                {
                    var webhook = payload.Deserialize<PaymobWebhookDTO>(opts);
                    if (webhook?.Obj != null)
                        await _paymentService.HandleTransactionWebhookAsync(webhook, hmac);
                }
            }
            catch (System.Exception)
            {
                // Swallow — never make Paymob retry on our internal error.
            }

            return Ok(new { message = "received" });
        }

        // The app relays Paymob's signed redirect callback here after checkout closes,
        // so a card payment settles without depending on the async webhook.
        [HttpPost("confirm-callback")]
        public async Task<IActionResult> ConfirmCallback([FromBody] PaymentCallbackDTO dto)
        {
            var raw = dto?.Query ?? string.Empty;
            // Accept either a full redirect URL or just the query string.
            var qIndex = raw.IndexOf('?');
            if (qIndex >= 0) raw = raw[(qIndex + 1)..];

            var query = QueryHelpers.ParseQuery(raw)
                .ToDictionary(kv => kv.Key, kv => kv.Value.ToString());

            var result = await _paymentService.ConfirmPaymentCallbackAsync(query);
            return StatusCode(result.StatusCode, result.Message);
        }

        [HttpGet("status/{tripId}")]
        public async Task<IActionResult> GetPaymentStatus(string tripId)
        {
            var response = await _paymentService.GetPaymentStatusAsync(tripId);
            if (response.IsSuccess)
            {
                return StatusCode(response.StatusCode, new { message = response.Message , data=response.Data });
            }

            return StatusCode(response.StatusCode, response.Message);
        }

        // Saved cards for the authenticated user (card-on-file). The user id comes
        // from the JWT, never the client, so one user can't read another's cards.
        [HttpGet("saved-cards")]
        public async Task<IActionResult> GetSavedCards()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
            {
                return Unauthorized();
            }
            var result = await _paymentService.GetSavedCardsAsync(userId);
            return StatusCode(result.StatusCode,
                result.IsSuccess ? (object)result.Data : result.Message);
        }

        [HttpDelete("saved-cards/{cardId:int}")]
        public async Task<IActionResult> DeleteSavedCard(int cardId)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
            {
                return Unauthorized();
            }
            var result = await _paymentService.DeleteSavedCardAsync(userId, cardId);
            return StatusCode(result.StatusCode, result.Message);
        }

        // Start an "add card" verification checkout for the authenticated user.
        [HttpPost("add-card")]
        public async Task<IActionResult> AddCard()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
            {
                return Unauthorized();
            }
            var result = await _paymentService.AddCardIntentAsync(userId);
            return StatusCode(result.StatusCode,
                result.IsSuccess ? (object)result.Data : result.Message);
        }

    }
}
