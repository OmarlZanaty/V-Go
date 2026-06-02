using Masafet_Elseka.Application.DTOs.Payment;
using Masafet_Elseka.Application.DTOs.Payment.PayMob;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.Interfaces.IPaymentService
{
    public interface IPaymentService
    {
        Task<Response<PaymobIntentResponseDTO>> CreatePaymentIntentAsync(PaymentRequestDTO request);
        Task<Response<string>> HandleTransactionWebhookAsync(PaymobWebhookDTO webhook /*PaymobTransactionDTO webhook*/, string hmac);
        Task<Response<string>> HandleTokenWebhookAsync(PaymobCardTokenDTO webhook, string hmac);
        Task<Response<Payment>> GetPaymentStatusAsync(string tripId);
        Task<Response<string>> PayTripInCashAsync(string tripId, string userId);
    }
}
