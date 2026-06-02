using Masafet_Elseka.Application.DTOs.PricingRule;
using Masafet_Elseka.Application.Response;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.Interfaces.IPricingRuleService
{
    public interface IPricingRuleService
    {
         Task<Response<string>> SavePricingRuleAsync(PricingRuleDTO model);
         Task<Response<Dictionary<string, decimal>>> GetPricePerKillo();
        public Task<Response<string>> SetDriverCommission(decimal commissionPercentage);
        public Task<Response<decimal>> GetDriverCommission();
    }
}
