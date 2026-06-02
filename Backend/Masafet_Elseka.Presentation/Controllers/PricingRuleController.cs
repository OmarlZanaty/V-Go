using Masafet_Elseka.Application.DTOs.PricingRule;
using Masafet_Elseka.Application.Interfaces.IPricingRuleService;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace Masafet_Elseka.Presentation.Controllers
{
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    [Route("api/[controller]")]
    [ApiController]
    public class PricingRuleController : ControllerBase
    {

        private readonly IPricingRuleService _pricingRuleService;

        public PricingRuleController(IPricingRuleService pricingRuleService)
        {
            _pricingRuleService = pricingRuleService;
        }

        [Authorize(Roles = "Admin, Dispatcher, Accountant")]
        [HttpPost]
        public async Task<IActionResult> AddPricePerKillo(PricingRuleDTO model)
        {
            if (model == null)
            {
                return BadRequest("نموذج البيانات غير صالح");
            }
            var result = await _pricingRuleService.SavePricingRuleAsync(model);
            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, new { message = result.Message });
            }
            return StatusCode(result.StatusCode, new { message = result.Message });
        }

        [Authorize(Roles = "Admin, Dispatcher, Client, Accountant, Driver")]
        [HttpGet("getPricePerKillo")]
        public async Task<IActionResult> GetPricePerKillo()
        {
            var result = await _pricingRuleService.GetPricePerKillo();
            if (result.IsSuccess)
            {
               return StatusCode(result.StatusCode, new { message = result.Message , Data= result.Data });
            }
            return StatusCode(result.StatusCode, new { Message = result.Message });
        }

        [Authorize(Roles = "Admin, Dispatcher, Accountant")]
        [HttpPost("setDriverCommission")]
        public async Task<IActionResult> SetDriverCommission([FromQuery] decimal commissionPercentage)
        {
            var result = await _pricingRuleService.SetDriverCommission(commissionPercentage);
            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, new { message = result.Message });
            }
            return StatusCode(result.StatusCode, new { Message = result.Message });
        }

        [Authorize(Roles = "Admin, Dispatcher, Accountant, Driver")]
        [HttpGet("getDriverCommission")]
        public async Task<IActionResult> GetDriverCommission()
        {
            var result = await _pricingRuleService.GetDriverCommission();
            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, new { message = result.Message, Data = result.Data });
            }
            return StatusCode(result.StatusCode, new { Message = result.Message });
        }
    }
}
