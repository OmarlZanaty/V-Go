using Masafet_Elseka.Application.DTOs.Payment;
using Masafet_Elseka.Application.DTOs.Payment.PayMob;
using Masafet_Elseka.Application.Interfaces.IPaymentService;
using Masafet_Elseka.Application.Interfaces.ITripService;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Const;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Data;
using Masafet_Elseka.Infrastructure.Hubs;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Serilog;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using System.Transactions;

namespace Masafet_Elseka.Infrastructure.Services.PaymentService
{
    public class PaymentService:IPaymentService
    {
        private readonly HttpClient _httpClient;
        private readonly Context _context;
        private readonly IConfiguration _configuration;
        private readonly IHubContext<TripHub> _tripHub;
        private readonly ITripService _tripService;

        public PaymentService(HttpClient httpClient, Context context, IConfiguration configuration, IHubContext<TripHub> tripHub, ITripService tripService)
        {
            _httpClient = httpClient;
            _context = context;
            _configuration = configuration;
            _tripHub = tripHub;
            _tripService = tripService;
        }

        public async Task<Response<PaymobIntentResponseDTO>> CreatePaymentIntentAsync(PaymentRequestDTO request)
        {
            using var transaction = await _context.Database.BeginTransactionAsync();
            try
            {
                var user= await _context.Users.FindAsync(request.UserId);
                if (user == null)
                {
                    return Response<PaymobIntentResponseDTO>.Failure("المستخدم غير موجود", 404);
                }

                if(_context.Payments.Any(p=>p.TripId==request.TripId && p.Status==PaymentStatus.Paid))
                {
                    return Response<PaymobIntentResponseDTO>.Failure("تم دفع هذه الرحلة مسبقاً", 400);
                }

                var payment = new Payment
                {
                    UserId = request.UserId,
                    TripId = request.TripId,
                    Amount = request.Price,
                    Currency = request.Currency,
                    CreatedAt = DateTime.Now.ToEgyptTime(),
                    Status=PaymentStatus.Pending
                };
                _context.Payments.Add(payment);

                //var savedCards = _context.SavedCards
                //    .Where(c => c.UserId == request.UserId)
                //    .Select(c => new
                //    {
                //        c.Token
                //    }).ToArray();

                var body = new
                {
                    amount = request.Price * 100,
                    currency = request.Currency,
                    merchant_order_id = payment.Id,
                    payment_methods = new[] { "cardintegrationliveid", "walletintegrationliveid" },

                    #region for Test
                    // ---> test credentials (used on development)
                    //payment_methods = new[] { "cardintegrationid", "walletintegrationid" }, 
                    #endregion

                    //card_tokens = savedCards.Any() ? savedCards : null,
                    billing_data = new
                    {
                        first_name = user.FullName,
                        last_name = "NA",
                        phone_number = user.PhoneNumber,
                        email = user.Email,
                    }
                };

                using var requestMessage = new HttpRequestMessage(HttpMethod.Post,
                    "https://accept.paymob.com/v1/intention/");

                requestMessage.Headers.Authorization =
                    new System.Net.Http.Headers.AuthenticationHeaderValue("Token", _configuration["Paymob:SecretKey"]);
                requestMessage.Content = JsonContent.Create(body);
                
                var response = await _httpClient.SendAsync(requestMessage);
                response.EnsureSuccessStatusCode();
                var intentResponse = await response.Content.ReadFromJsonAsync<PaymobIntentResponseDTO>();
                payment.OrderId = intentResponse.IntentionOrderId.ToString();
                await _context.SaveChangesAsync();

                if (intentResponse == null)
                {
                    return Response<PaymobIntentResponseDTO>.Failure("فشل في إنشاء الدفع", 400);
                }
                intentResponse.PublicKey = _configuration["Paymob:PublicKey"];

                transaction.Commit();
                return Response<PaymobIntentResponseDTO>.Success(intentResponse, "تم إنشاء الدفع بنجاح", 200);
            }
            catch (HttpRequestException httpEx)
            {
                transaction.Rollback();
                return Response<PaymobIntentResponseDTO>.Failure($"خطأ في الاتصال بخدمة الدفع: {httpEx.Message}", 503);
            }
            catch (Exception ex)
            {
                transaction.Rollback();
                Log.Error(ex, "PaymentService CreatePaymentIntent error");
                return Response<PaymobIntentResponseDTO>.Failure("حدث خطأ غير متوقع، يرجى المحاولة لاحقًا.", 500);
            }
        }
        public async Task<Response<string>> HandleTransactionWebhookAsync(PaymobWebhookDTO webhook /*PaymobTransactionDTO webhook*/,string hmacSecret)
        {
            try
            {
                var concatenatedString = BuildTransactionConcatenatedString(webhook.Obj);

                var secret = _configuration["Paymob:HmacSecret"];
                if (string.IsNullOrEmpty(secret))
                {
                    Log.Error("Paymob:HmacSecret is not configured");
                    return Response<string>.Failure("خطأ في إعدادات الدفع", 500);
                }
                using var hmac = new HMACSHA512(Encoding.UTF8.GetBytes(secret));
                var computedHash = BitConverter.ToString(
                    hmac.ComputeHash(Encoding.UTF8.GetBytes(concatenatedString))
                ).Replace("-", "").ToLower();

                if (computedHash != hmacSecret.ToLower())
                {
                    return Response<string>.Failure("الطلب غير موثق (HMAC mismatch)", 401);
                }

                var payment = await _context.Payments
                    .Include(p => p.Trip).ThenInclude(t=>t.UserTrips)
                    .FirstOrDefaultAsync(p => p.OrderId==webhook.Obj.Order.Id.ToString());

                if (payment == null)
                {
                    return Response<string>.Failure("عملية الدفع غير موجودة", 404);
                }

                payment.Status = webhook.Obj.Success ? PaymentStatus.Paid : PaymentStatus.Failed;
                payment.Method= webhook.Obj.SourceData?.Type;
                payment.UpdatedAt = DateTime.Now.ToEgyptTime();
                payment.TransactionId = webhook.Obj.Id.ToString();

                await _context.SaveChangesAsync();

                var driverId=payment.Trip.UserTrips
                    .FirstOrDefault(ut=>ut.UserId!=payment.UserId && ut.Role==UserTripRole.Driver)?.UserId;
                await NotifyClientAndDriver(payment.UserId, driverId!, payment.Status);

                return Response<string>.Success("تم تحديث حالة الدفع", "تم تحديث حالة الدفع", 200);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "PaymentService webhook error");
                return Response<string>.Failure("خطأ أثناء معالجة الطلب، يرجى المحاولة لاحقًا.", 500);
            }
        }

        public async Task<Response<string>> HandleTokenWebhookAsync(PaymobCardTokenDTO webhook, string hmacSecret)
        {
            try
            {
                var concatenatedString = BuildTokenConcatenatedString(webhook);
                var secret = _configuration["Paymob:HmacSecret"];
                if (string.IsNullOrEmpty(secret))
                {
                    Log.Error("Paymob:HmacSecret is not configured");
                    return Response<string>.Failure("خطأ في إعدادات الدفع", 500);
                }
                using var hmac = new HMACSHA512(Encoding.UTF8.GetBytes(secret));

                var computedHash = BitConverter.ToString(
                    hmac.ComputeHash(Encoding.UTF8.GetBytes(concatenatedString))
                ).Replace("-", "").ToLower();

                if (computedHash != hmacSecret.ToLower())
                {
                    return Response<string>.Failure("الطلب غير موثق (HMAC mismatch)", 401);
                }

                var payment = await _context.Payments
                    .FirstOrDefaultAsync(p => p.OrderId == webhook.OrderId.ToString());

                if (payment == null)
                {
                    return Response<string>.Failure("عملية الدفع غير موجودة", 404);
                }

                var existingCard = await _context.SavedCards
                    .FirstOrDefaultAsync(c => c.UserId == payment.UserId && c.Token == webhook.Token);
                if (existingCard != null)
                {
                    return Response<string>.Success("البطاقة محفوظة مسبقاً", "البطاقة محفوظة مسبقاً", 200);
                }

                var card = new SavedCard
                {
                    UserId = payment!.UserId,
                    Token = webhook.Token,
                    MaskedPan = webhook.MaskedPan,
                    CreatedAt = DateTime.Now.ToEgyptTime(),
                };

                _context.SavedCards.Add(card);
                await _context.SaveChangesAsync();

                return Response<string>.Success("تم حفظ البطاقة بنجاح", "تم حفظ البطاقة بنجاح", 200);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "PaymentService webhook error");
                return Response<string>.Failure("خطأ أثناء معالجة الطلب، يرجى المحاولة لاحقًا.", 500);
            }
        }

        public async Task<Response<Payment>> GetPaymentStatusAsync(string tripId)
        {
            var payment = await _context.Payments
                .OrderByDescending(p => p.CreatedAt)
                .FirstOrDefaultAsync(p => p.TripId == tripId);

            if (payment == null)
            {
                return Response<Payment>.Failure("لا يوجد دفع مسجل لهذه الرحلة", 404);
            }

            return Response<Payment>.Success(payment, "تم جلب حالة الدفع", 200);
        }

        public async Task<Response<string>> PayTripInCashAsync(string tripId, string userId)
        {
            try
            {
                var trip = await _context.Trips
                    .Include(t => t.Payment)
                    .FirstOrDefaultAsync(t => t.Id == tripId);
                if (trip == null)
                {
                    return Response<string>.Failure("الرحلة غير موجودة", 404);
                }
                var isPaid = trip.Payment.Any(p => p.Status == PaymentStatus.Paid);
                if (isPaid)
                {
                    return Response<string>.Failure("تم دفع هذه الرحلة بالفعل", 400);
                }
                var payment = new Payment
                {
                    Amount = trip.Price,
                    Currency = "EGP",
                    Method = "Cash",
                    Status = PaymentStatus.Paid,
                    CreatedAt = DateTime.Now.ToEgyptTime(),
                    UpdatedAt = DateTime.Now.ToEgyptTime(),
                    UserId = userId!,
                    TripId = tripId
                };

                _context.Payments.Add(payment);
                await _context.SaveChangesAsync();
                return Response<string>.Success("سيتم دفع الرحلة نقدا للسائق", "سيتم دفع الرحلة نقدا للسائق", 200);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "PaymentService cash payment error");
                return Response<string>.Failure("حدث خطأ أثناء محاولة دفع الرحلة نقدا", "حدث خطأ أثناء محاولة دفع الرحلة نقدا", 500);
            }
        }

        //Helpers
        private string BuildTransactionConcatenatedString(PaymobTransactionDTO obj)
        {  
            return
                obj.AmountCents +
                obj.CreatedAt +
                (obj.Currency ?? "") +
                obj.ErrorOccured.ToString().ToLower() +
                obj.HasParentTransaction.ToString().ToLower() +
                obj.Id.ToString() +
                obj.IntegrationId.ToString() +
                obj.Is3dSecure.ToString().ToLower() +
                obj.IsAuth.ToString().ToLower() +
                obj.IsCapture.ToString().ToLower() +
                obj.IsRefunded.ToString().ToLower() +
                obj.IsStandalonePayment.ToString().ToLower() +
                obj.IsVoided.ToString().ToLower() +
                obj.Order.Id.ToString() +
                obj.Owner.ToString() +
                obj.Pending.ToString().ToLower() +
                (obj.SourceData?.Pan ?? "") +
                (obj.SourceData?.SubType ?? "") +
                (obj.SourceData?.Type ?? "") +
                obj.Success.ToString().ToLower();
        }

        private string BuildTokenConcatenatedString(PaymobCardTokenDTO obj)
        {
            return
                (obj.CardSubtype ?? "") +
                obj.CreatedAt +
                (obj.Email ?? "") +
                obj.Id.ToString() +
                obj.MaskedPan +
                obj.MerchantId.ToString() +
                obj.OrderId.ToString() +
                obj.Token;
        }

        private async Task NotifyClientAndDriver(string userId, string driverId, PaymentStatus status)
        {
            var response = new
            {
                Status = status.ToString(),
                Message = status == PaymentStatus.Paid ? "تم دفع الرحلة بنجاح" : "فشل في عملية الدفع"
            };

            await _tripHub.Clients.Group(HubGroups.User(userId))
                .SendAsync(HubEvents.TripPaymentUpdated, response);
            if (!string.IsNullOrEmpty(driverId))
            {
                await _tripHub.Clients.Group(HubGroups.Driver(driverId))
                    .SendAsync(HubEvents.TripPaymentUpdated, response);
            }

            if (status == PaymentStatus.Paid)
            {
                var currentTrip = await _tripService.GetCurrentTrip(userId, UserTripRole.Client);
                if (currentTrip.IsSuccess && currentTrip.Data != null)
                {
                    await _tripHub.Clients.Group(HubGroups.User(userId))
                        .SendAsync(HubEvents.ReceiveCurrentTrip, currentTrip.Data);
                    if (!string.IsNullOrEmpty(driverId))
                    {
                        await _tripHub.Clients.Group(HubGroups.Driver(driverId))
                            .SendAsync(HubEvents.ReceiveCurrentTrip, currentTrip.Data);
                    }
                }
            }
        }
    }
}
