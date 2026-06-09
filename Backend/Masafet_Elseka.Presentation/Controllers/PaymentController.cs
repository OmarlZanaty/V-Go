using Masafet_Elseka.Application.DTOs.Payment;
using Masafet_Elseka.Application.DTOs.Payment.PayMob;
using Masafet_Elseka.Application.Interfaces.IPaymentService;
using Masafet_Elseka.Application.Response;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
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
        public async Task<IActionResult> HandleWebhook([FromBody] PaymobWebhookDTO webhook, [FromQuery] string hmac)
        {
            if (webhook == null)
            {
                return BadRequest("Invalid payload");
            }

            //var result = null as Response<string>;

            //switch (webhook.Type)
            //{
            //    case "TRANSACTION":
            //        result = await _paymentService.HandleTransactionWebhookAsync(
            //            webhook.Obj.Deserialize<PaymobTransactionDTO>(), hmac);
            //        break;
            //    case "TOKEN":
            //        result = await _paymentService.HandleTokenWebhookAsync(
            //            webhook.Obj.Deserialize<PaymobCardTokenDTO>(), hmac);
            //        break;
            //}

            var result = await _paymentService.HandleTransactionWebhookAsync(webhook, hmac);

            if (result != null && result.IsSuccess)
            {
                return Ok(new { message = result.Message });
            }
            else
            {
                return BadRequest(new { error = result?.Message });
            }
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

    }
}
