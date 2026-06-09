using Masafet_Elseka.Application.DTOs.PricingRule;
using Masafet_Elseka.Application.Interfaces.IPricingRuleService;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Infrastructure.UOW;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Masafet_Elseka.Infrastructure.Services.PricingRoleService
{
    public class PricingRuleService : IPricingRuleService
    {
        private readonly IUnitOfWork unitOfWork;

        public PricingRuleService(IUnitOfWork unitOfWork)
        {
            this.unitOfWork = unitOfWork;
        }

        public async Task<Response<string>> SavePricingRuleAsync(PricingRuleDTO model)
        {
            try
            {
                if (model.PricePerKillo <= 0)
                {
                    return Response<string>.Failure("سعر الكيلو يجب أن يكون أكبر من صفر", 400);
                }

                var existing = await unitOfWork.PricingRules.GetFirstOrDefaultAsync();

                if (existing != null)
                {
                    existing.PricePerKm = model.PricePerKillo;
                    existing.LastUpdated = DateTime.Now.ToEgyptTime();
                    await unitOfWork.SaveAsync();
                }
                else
                {
                    var priceModel = new PricingRule
                    {
                        PricePerKm = model.PricePerKillo,
                        LastUpdated = DateTime.Now.ToEgyptTime(),
                    };

                    await unitOfWork.PricingRules.AddAsync(priceModel);
                    await unitOfWork.SaveAsync();
                }

                return Response<string>.Success("تم حفظ سعر الكيلو للرحلات بنجاح", "تم حفظ سعر الكيلو للرحلات بنجاح", 201);
            }
            catch (Exception ex)
            {
                return Response<string>.Failure("حدث خطأ أثناء حفظ إعدادات قاعدة التسعير", "حدث خطأ غير متوقع، يرجى المحاولة لاحقًا", 500);
            }
        }

        public async Task<Response<Dictionary<string, decimal>>> GetPricePerKillo()
        {
            try
            {
                var pricingPerKillo = await unitOfWork.PricingRules.GetFirstOrDefaultAsync();
                if (pricingPerKillo == null)
                {
                    return Response<Dictionary<string, decimal>>.Failure("لا توجد قاعدة تسعير متاحة", 404);
                }
                var result = new Dictionary<string, decimal>
                {
                    { "PricePerKillo", pricingPerKillo.PricePerKm }
                };
                return Response<Dictionary<string, decimal>>.Success(result, "تم استرجاع سعر الكيلو بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<Dictionary<string, decimal>>.Failure("حدث خطأ أثناء استرجاع سعر الكيلو", 500);
            }
        }

        public async Task<Response<string>> SetDriverCommission(decimal commissionPercentage)
        {
            try
            {
                if (commissionPercentage < 0 || commissionPercentage > 100)
                {
                    return Response<string>.Failure("نسبة العمولة يجب أن تكون بين 0 و 100", 400);
                }

                var existing = await unitOfWork.PricingRules.GetFirstOrDefaultAsync();
                if (existing != null)
                {
                    existing.DriverCommissionPercentage = commissionPercentage;
                    existing.LastUpdated = DateTime.Now.ToEgyptTime();
                    await unitOfWork.SaveAsync();
                }
                else
                {
                    var pricingRule = new PricingRule
                    {
                        DriverCommissionPercentage = commissionPercentage,
                        LastUpdated = DateTime.Now.ToEgyptTime(),
                    };
                    await unitOfWork.PricingRules.AddAsync(pricingRule);
                    await unitOfWork.SaveAsync();
                }

                return Response<string>.Success("تم تحديث نسبة عمولة السائق بنجاح", "تم تحديث نسبة عمولة السائق بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<string>.Failure("حدث خطأ أثناء تحديث نسبة عمولة السائق", 500);
            }
        }

        public async Task<Response<decimal>> GetDriverCommission()
        {
            try
            {
                var pricingRule = await unitOfWork.PricingRules.GetFirstOrDefaultAsync();
                if (pricingRule == null)
                {
                    return Response<decimal>.Failure("لا توجد قاعدة تسعير متاحة", 404);
                }
                return Response<decimal>.Success(pricingRule.DriverCommissionPercentage, "تم استرجاع نسبة عمولة السائق بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<decimal>.Failure("حدث خطأ أثناء استرجاع نسبة عمولة السائق", 500);
            }
        }
    }
}