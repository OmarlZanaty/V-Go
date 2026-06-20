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
        private readonly Application.Interfaces.INotificationService.INotificationService _notificationService;

        public PaymentService(HttpClient httpClient, Context context, IConfiguration configuration, IHubContext<TripHub> tripHub, ITripService tripService, Application.Interfaces.INotificationService.INotificationService notificationService)
        {
            _httpClient = httpClient;
            _context = context;
            _configuration = configuration;
            _tripHub = tripHub;
            _tripService = tripService;
            _notificationService = notificationService;
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

                // The user's previously-saved card tokens (populated by HandleTokenWebhookAsync).
                // Passed to Paymob as `card_tokens` so saved cards can be used for one-click payment.
                var savedCardTokens = await _context.SavedCards
                    .Where(c => c.UserId == request.UserId && c.IsActive)
                    .Select(c => c.Token)
                    .ToArrayAsync();

                var body = new Dictionary<string, object?>
                {
                    ["amount"] = request.Price * 100,
                    ["currency"] = request.Currency,
                    ["merchant_order_id"] = payment.Id,
                    // Integration IDs come from config (Paymob:CardIntegrationId / WalletIntegrationId).
                    ["payment_methods"] = new[]
                    {
                        int.Parse(_configuration["Paymob:CardIntegrationId"] ?? "0"),
                        int.Parse(_configuration["Paymob:WalletIntegrationId"] ?? "0")
                    },
                    // Paymob rejects the intention (400) if billing fields are blank.
                    // Phone-registered users have no email, so synthesize a valid one.
                    ["billing_data"] = new
                    {
                        first_name = string.IsNullOrWhiteSpace(user.FullName) ? "Customer" : user.FullName,
                        last_name = "NA",
                        phone_number = string.IsNullOrWhiteSpace(user.PhoneNumber) ? "+201000000000" : user.PhoneNumber,
                        email = string.IsNullOrWhiteSpace(user.Email) ? $"user_{user.Id}@vgo-eg.com" : user.Email,
                    }
                };

                // Only include card_tokens when the user actually has saved cards, so the
                // default new-card flow is byte-for-byte unchanged for everyone else.
                if (savedCardTokens.Length > 0)
                {
                    body["card_tokens"] = savedCardTokens;
                }

                using var requestMessage = new HttpRequestMessage(HttpMethod.Post,
                    "https://accept.paymob.com/v1/intention/");

                requestMessage.Headers.Authorization =
                    new System.Net.Http.Headers.AuthenticationHeaderValue("Token", _configuration["Paymob:SecretKey"]);
                requestMessage.Content = JsonContent.Create(body);
                
                var response = await _httpClient.SendAsync(requestMessage);
                if (!response.IsSuccessStatusCode)
                {
                    var errBody = await response.Content.ReadAsStringAsync();
                    Log.Error("Paymob intention failed: {Status} body={Body}", response.StatusCode, errBody);
                    return Response<PaymobIntentResponseDTO>.Failure(
                        "تعذّر إنشاء عملية الدفع، يرجى المحاولة لاحقًا أو الدفع نقداً.", 503);
                }
                var intentResponse = await response.Content.ReadFromJsonAsync<PaymobIntentResponseDTO>();

                // Validate the gateway response BEFORE dereferencing it. Previously the null
                // check ran after `intentResponse.IntentionOrderId`, so a null/unparseable
                // response threw an NRE. Returning here disposes the transaction without a
                // commit, so no partial Pending payment row is left behind.
                if (intentResponse == null)
                {
                    return Response<PaymobIntentResponseDTO>.Failure("فشل في إنشاء الدفع", 400);
                }

                payment.OrderId = intentResponse.IntentionOrderId.ToString();
                await _context.SaveChangesAsync();

                intentResponse.PublicKey = _configuration["Paymob:PublicKey"];

                transaction.Commit();
                return Response<PaymobIntentResponseDTO>.Success(intentResponse, "تم إنشاء الدفع بنجاح", 200);
            }
            catch (HttpRequestException httpEx)
            {
                transaction.Rollback();
                Log.Error(httpEx, "PaymentService CreatePaymentIntent HTTP error");
                return Response<PaymobIntentResponseDTO>.Failure("تعذّر الاتصال بخدمة الدفع. يرجى المحاولة لاحقًا.", 503);
            }
            catch (Exception ex)
            {
                transaction.Rollback();
                Log.Error(ex, "PaymentService CreatePaymentIntent error");
                return Response<PaymobIntentResponseDTO>.Failure("حدث خطأ غير متوقع، يرجى المحاولة لاحقًا.", 500);
            }
        }
        // ===================== Visa Pre-Authorization (Auth & Capture) =====================

        // Cached Paymob auth token (legacy /api/auth/tokens), shared across scoped
        // PaymentService instances. Paymob tokens last 1 hour; we refresh after 55 min.
        private static string? _cachedAuthToken;
        private static DateTime _authTokenExpiresAtUtc;
        private static readonly SemaphoreSlim _authLock = new(1, 1);

        private string PaymobBaseUrl =>
            _configuration["Paymob:BaseUrl"] ?? "https://accept.paymob.com";

        // 4.1 — Create a pre-authorization (hold) intention. Mirrors CreatePaymentIntentAsync
        // but uses the Auth integration id so the resulting transaction is a hold, not a sale.
        // Returns the same unified-checkout payload (client_secret + public key) the Flutter
        // app already consumes, so the mobile initiation path is unchanged.
        public async Task<Response<PaymobIntentResponseDTO>> InitiatePreAuthAsync(PaymentRequestDTO request)
        {
            var authIntegrationId = _configuration["Paymob:AuthIntegrationId"];
            if (string.IsNullOrWhiteSpace(authIntegrationId) || authIntegrationId == "0")
            {
                Log.Warning("InitiatePreAuth called but Paymob:AuthIntegrationId is not configured");
                return Response<PaymobIntentResponseDTO>.Failure("خدمة الدفع غير متاحة حالياً، يرجى الدفع نقداً", 503);
            }

            using var transaction = await _context.Database.BeginTransactionAsync();
            try
            {
                var user = await _context.Users.FindAsync(request.UserId);
                if (user == null)
                {
                    return Response<PaymobIntentResponseDTO>.Failure("المستخدم غير موجود", 404);
                }

                if (_context.Payments.Any(p => p.TripId == request.TripId &&
                        (p.Status == PaymentStatus.Paid || p.Status == PaymentStatus.Captured ||
                         p.Status == PaymentStatus.PreAuthSuccess)))
                {
                    return Response<PaymobIntentResponseDTO>.Failure("تم دفع أو حجز مبلغ هذه الرحلة مسبقاً", 400);
                }

                var payment = new Payment
                {
                    UserId = request.UserId,
                    TripId = request.TripId,
                    Amount = request.Price,
                    Currency = request.Currency,
                    CreatedAt = DateTime.Now.ToEgyptTime(),
                    Status = PaymentStatus.PreAuthInitiated,
                    // Paymob holds funds ~7 days; void at +6 to stay safely inside the window.
                    PreauthExpiresAt = DateTime.Now.ToEgyptTime().AddDays(6)
                };
                _context.Payments.Add(payment);

                var body = new Dictionary<string, object?>
                {
                    ["amount"] = (int)Math.Round(request.Price * 100),
                    ["currency"] = request.Currency,
                    ["merchant_order_id"] = payment.Id,
                    ["payment_methods"] = new[] { int.Parse(authIntegrationId) },
                    // Paymob rejects the intention (400) if billing fields are blank.
                    // Phone-registered users have no email, so synthesize a valid one.
                    ["billing_data"] = new
                    {
                        first_name = string.IsNullOrWhiteSpace(user.FullName) ? "Customer" : user.FullName,
                        last_name = "NA",
                        phone_number = string.IsNullOrWhiteSpace(user.PhoneNumber) ? "+201000000000" : user.PhoneNumber,
                        email = string.IsNullOrWhiteSpace(user.Email) ? $"user_{user.Id}@vgo-eg.com" : user.Email,
                    }
                };

                using var requestMessage = new HttpRequestMessage(HttpMethod.Post,
                    $"{PaymobBaseUrl}/v1/intention/");
                requestMessage.Headers.Authorization =
                    new System.Net.Http.Headers.AuthenticationHeaderValue("Token", _configuration["Paymob:SecretKey"]);
                requestMessage.Content = JsonContent.Create(body);

                using var cts = new CancellationTokenSource(TimeSpan.FromMilliseconds(15000));
                var response = await _httpClient.SendAsync(requestMessage, cts.Token);
                response.EnsureSuccessStatusCode();
                var intentResponse = await response.Content.ReadFromJsonAsync<PaymobIntentResponseDTO>(cancellationToken: cts.Token);

                if (intentResponse == null)
                {
                    return Response<PaymobIntentResponseDTO>.Failure("فشل في إنشاء الحجز المسبق", 400);
                }

                payment.OrderId = intentResponse.IntentionOrderId.ToString();
                await _context.SaveChangesAsync();

                intentResponse.PublicKey = _configuration["Paymob:PublicKey"];

                await transaction.CommitAsync();
                return Response<PaymobIntentResponseDTO>.Success(intentResponse, "تم إنشاء الحجز المسبق بنجاح", 200);
            }
            catch (HttpRequestException httpEx)
            {
                await transaction.RollbackAsync();
                Log.Error(httpEx, "PaymentService InitiatePreAuth HTTP error");
                return Response<PaymobIntentResponseDTO>.Failure("تعذّر الاتصال بخدمة الدفع. يرجى المحاولة لاحقاً أو الدفع نقداً.", 503);
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync();
                Log.Error(ex, "PaymentService InitiatePreAuth error");
                return Response<PaymobIntentResponseDTO>.Failure("حدث خطأ غير متوقع، يرجى المحاولة لاحقاً.", 500);
            }
        }

        // 4.3 — Capture the held amount when the ride completes. Retries once after a 5s
        // backoff on transient failure; on final failure marks CaptureFailed and alerts admin.
        public async Task<Response<Payment>> CaptureRidePaymentAsync(string tripId)
        {
            try
            {
                var payment = await _context.Payments
                    .Where(p => p.TripId == tripId)
                    .OrderByDescending(p => p.CreatedAt)
                    .FirstOrDefaultAsync();

                if (payment == null)
                {
                    return Response<Payment>.Failure("لا يوجد دفع مسجل لهذه الرحلة", 404);
                }
                if (payment.Status != PaymentStatus.PreAuthSuccess || string.IsNullOrEmpty(payment.PreauthTransactionId))
                {
                    return Response<Payment>.Failure("لا يمكن تحصيل المبلغ: لا يوجد حجز ناجح لهذه الرحلة", 400);
                }

                var amountCents = (int)Math.Round(payment.Amount * 100);
                var captured = false;
                for (var attempt = 0; attempt < 2 && !captured; attempt++)
                {
                    if (attempt > 0)
                    {
                        await Task.Delay(TimeSpan.FromSeconds(5)); // single 5s backoff retry
                    }
                    try
                    {
                        var token = await AuthenticateAsync();
                        captured = await CaptureTransactionAsync(token, payment.PreauthTransactionId, amountCents);
                    }
                    catch (Exception ex)
                    {
                        Log.Error(ex, "Capture attempt {Attempt} failed for trip {TripId}", attempt + 1, tripId);
                    }
                }

                if (!captured)
                {
                    payment.Status = PaymentStatus.CaptureFailed;
                    payment.FailureReason = "Capture failed at Paymob after retry";
                    payment.UpdatedAt = DateTime.Now.ToEgyptTime();
                    await _context.SaveChangesAsync();
                    Log.Error("ADMIN ALERT: capture failed for trip {TripId}, payment {PaymentId}, amount {Amount}",
                        tripId, payment.Id, payment.Amount);
                    await AlertAdminsAsync("فشل تحصيل دفعة فيزا",
                        $"تعذّر تحصيل مبلغ الرحلة {tripId}. يرجى المتابعة يدوياً.");
                    return Response<Payment>.Failure("فشل تحصيل المبلغ من البطاقة", 500);
                }

                // Optimistic update; the capture webhook (is_capture) confirms and sets the real id.
                payment.Status = PaymentStatus.Captured;
                payment.CaptureTransactionId ??= payment.PreauthTransactionId;
                payment.UpdatedAt = DateTime.Now.ToEgyptTime();
                await _context.SaveChangesAsync();
                return Response<Payment>.Success(payment, "تم تحصيل المبلغ بنجاح", 200);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "CaptureRidePayment error for trip {TripId}", tripId);
                return Response<Payment>.Failure("حدث خطأ أثناء تحصيل المبلغ", 500);
            }
        }

        // 4.4 — Void (release) the held amount when the ride is cancelled before capture.
        public async Task<Response<Payment>> VoidRidePaymentAsync(string tripId)
        {
            try
            {
                var payment = await _context.Payments
                    .Where(p => p.TripId == tripId)
                    .OrderByDescending(p => p.CreatedAt)
                    .FirstOrDefaultAsync();

                if (payment == null)
                {
                    return Response<Payment>.Failure("لا يوجد دفع مسجل لهذه الرحلة", 404);
                }
                if (payment.Status != PaymentStatus.PreAuthSuccess || string.IsNullOrEmpty(payment.PreauthTransactionId))
                {
                    return Response<Payment>.Failure("لا يوجد حجز ناجح يمكن إلغاؤه لهذه الرحلة", 400);
                }

                var voided = false;
                try
                {
                    var token = await AuthenticateAsync();
                    voided = await VoidTransactionAsync(token, payment.PreauthTransactionId);
                }
                catch (Exception ex)
                {
                    Log.Error(ex, "Void call failed for trip {TripId}", tripId);
                }

                if (!voided)
                {
                    payment.Status = PaymentStatus.VoidFailed;
                    payment.FailureReason = "Void failed at Paymob";
                    payment.UpdatedAt = DateTime.Now.ToEgyptTime();
                    await _context.SaveChangesAsync();
                    Log.Error("ADMIN ALERT: void failed for trip {TripId}, payment {PaymentId}", tripId, payment.Id);
                    await AlertAdminsAsync("فشل إلغاء حجز فيزا",
                        $"تعذّر إلغاء حجز مبلغ الرحلة {tripId}. يرجى المتابعة يدوياً.");
                    return Response<Payment>.Failure("فشل إلغاء الحجز", 500);
                }

                payment.Status = PaymentStatus.Voided;
                payment.UpdatedAt = DateTime.Now.ToEgyptTime();
                await _context.SaveChangesAsync();
                return Response<Payment>.Success(payment, "تم إلغاء الحجز بنجاح", 200);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "VoidRidePayment error for trip {TripId}", tripId);
                return Response<Payment>.Failure("حدث خطأ أثناء إلغاء الحجز", 500);
            }
        }

        // Edge case 5 — cron sweep: void any pre-auth still held past its expiry window.
        public async Task<int> VoidExpiredPreAuthsAsync()
        {
            var now = DateTime.Now.ToEgyptTime();
            var expired = await _context.Payments
                .Where(p => p.Status == PaymentStatus.PreAuthSuccess
                            && p.PreauthExpiresAt != null
                            && p.PreauthExpiresAt < now)
                .ToListAsync();

            var count = 0;
            foreach (var payment in expired)
            {
                var result = await VoidRidePaymentAsync(payment.TripId);
                if (result.IsSuccess)
                {
                    count++;
                    Log.Warning("Voided expired pre-auth for trip {TripId} (expired at {ExpiresAt})",
                        payment.TripId, payment.PreauthExpiresAt);
                }
            }
            return count;
        }

        // --- Raw Paymob calls (legacy auth token + acceptance endpoints) ---

        private async Task<string> AuthenticateAsync()
        {
            if (_cachedAuthToken != null && DateTime.UtcNow < _authTokenExpiresAtUtc)
            {
                return _cachedAuthToken;
            }
            await _authLock.WaitAsync();
            try
            {
                if (_cachedAuthToken != null && DateTime.UtcNow < _authTokenExpiresAtUtc)
                {
                    return _cachedAuthToken;
                }
                var apiKey = _configuration["Paymob:ApiKey"];
                if (string.IsNullOrWhiteSpace(apiKey))
                {
                    throw new InvalidOperationException("Paymob:ApiKey is not configured");
                }
                using var cts = new CancellationTokenSource(TimeSpan.FromMilliseconds(15000));
                var resp = await _httpClient.PostAsJsonAsync($"{PaymobBaseUrl}/api/auth/tokens",
                    new { api_key = apiKey }, cts.Token);
                resp.EnsureSuccessStatusCode();
                using var doc = JsonDocument.Parse(await resp.Content.ReadAsStringAsync(cts.Token));
                var token = doc.RootElement.GetProperty("token").GetString();
                _cachedAuthToken = token;
                _authTokenExpiresAtUtc = DateTime.UtcNow.AddMinutes(55);
                return token!;
            }
            finally
            {
                _authLock.Release();
            }
        }

        private async Task<bool> CaptureTransactionAsync(string authToken, string transactionId, int amountCents)
        {
            using var cts = new CancellationTokenSource(TimeSpan.FromMilliseconds(15000));
            var resp = await _httpClient.PostAsJsonAsync($"{PaymobBaseUrl}/api/acceptance/capture",
                new { auth_token = authToken, transaction_id = transactionId, amount_cents = amountCents }, cts.Token);
            if (!resp.IsSuccessStatusCode)
            {
                Log.Error("Paymob capture returned {Status} for transaction {TransactionId}", resp.StatusCode, transactionId);
                return false;
            }
            using var doc = JsonDocument.Parse(await resp.Content.ReadAsStringAsync(cts.Token));
            // Capture echoes the transaction object; trust its "success" flag when present.
            if (doc.RootElement.TryGetProperty("success", out var success))
            {
                return success.ValueKind == JsonValueKind.True ||
                       (success.ValueKind == JsonValueKind.String && bool.TryParse(success.GetString(), out var b) && b);
            }
            return true;
        }

        private async Task<bool> VoidTransactionAsync(string authToken, string transactionId)
        {
            using var cts = new CancellationTokenSource(TimeSpan.FromMilliseconds(15000));
            var resp = await _httpClient.PostAsJsonAsync($"{PaymobBaseUrl}/api/acceptance/void_refund/void",
                new { auth_token = authToken, transaction_id = transactionId }, cts.Token);
            if (!resp.IsSuccessStatusCode)
            {
                Log.Error("Paymob void returned {Status} for transaction {TransactionId}", resp.StatusCode, transactionId);
                return false;
            }
            using var doc = JsonDocument.Parse(await resp.Content.ReadAsStringAsync(cts.Token));
            if (doc.RootElement.TryGetProperty("success", out var success))
            {
                return success.ValueKind == JsonValueKind.True ||
                       (success.ValueKind == JsonValueKind.String && bool.TryParse(success.GetString(), out var b) && b);
            }
            return true;
        }

        // Best-effort admin alert for capture/void failures. Notifies all Admin-role users
        // via the existing notification service; failures here are logged, never thrown.
        private async Task AlertAdminsAsync(string title, string message)
        {
            try
            {
                var adminIds = await (from u in _context.Users
                                      join ur in _context.UserRoles on u.Id equals ur.UserId
                                      join r in _context.Roles on ur.RoleId equals r.Id
                                      where r.Name == "Admin"
                                      select u.Id).ToListAsync();
                foreach (var adminId in adminIds)
                {
                    await _notificationService.SendNotificationToUserAsync(adminId, title, message,
                        new Dictionary<string, string> { { "type", "payment_alert" } });
                }
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Failed sending admin payment-failure alert");
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

                var obj = webhook.Obj;
                payment.Method = obj.SourceData?.Type;
                payment.UpdatedAt = DateTime.Now.ToEgyptTime();
                payment.TransactionId = obj.Id.ToString();

                // Branch on the Paymob transaction type. is_voided / is_capture / is_auth
                // drive the pre-auth lifecycle; anything else is a legacy immediate sale.
                if (obj.IsVoided)
                {
                    payment.Status = PaymentStatus.Voided;
                }
                else if (obj.IsCapture)
                {
                    payment.Status = obj.Success ? PaymentStatus.Captured : PaymentStatus.CaptureFailed;
                    if (obj.Success)
                    {
                        payment.CaptureTransactionId = obj.Id.ToString();
                    }
                    else
                    {
                        payment.FailureReason = "Capture failed at gateway";
                    }
                }
                else if (obj.IsAuth)
                {
                    if (obj.Success)
                    {
                        payment.Status = PaymentStatus.PreAuthSuccess;
                        payment.PreauthTransactionId = obj.Id.ToString();
                        payment.PreauthExpiresAt ??= DateTime.Now.ToEgyptTime().AddDays(6);
                    }
                    else
                    {
                        payment.Status = PaymentStatus.PreAuthFailed;
                        payment.FailureReason = "Card declined at pre-authorization";
                    }
                }
                else
                {
                    payment.Status = obj.Success ? PaymentStatus.Paid : PaymentStatus.Failed;
                }

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
                .Include(p => p.Trip).ThenInclude(t => t.UserTrips)
                .OrderByDescending(p => p.CreatedAt)
                .FirstOrDefaultAsync(p => p.TripId == tripId);

            if (payment == null)
            {
                return Response<Payment>.Failure("لا يوجد دفع مسجل لهذه الرحلة", 404);
            }

            // Self-healing: if the card payment is still Pending, the async Paymob
            // webhook may never have arrived (webhook URL not configured, or a transient
            // delivery failure). Pull the truth straight from Paymob before answering, so
            // the captain's "verify payment" no longer hangs on a payment that succeeded.
            if (payment.Status == PaymentStatus.Pending)
            {
                await ReconcileFromGatewayAsync(payment);
            }

            return Response<Payment>.Success(payment, "تم جلب حالة الدفع", 200);
        }

        // Pull the latest transaction for this order directly from Paymob and apply it
        // locally (status + notify), mirroring the webhook. The reconciliation path that
        // makes online payments robust against missed webhooks.
        private async Task ReconcileFromGatewayAsync(Payment payment)
        {
            if (payment == null || string.IsNullOrEmpty(payment.OrderId)) return;
            if (!long.TryParse(payment.OrderId, out var orderId)) return;
            // The legacy transaction-inquiry needs Paymob:ApiKey (separate from the
            // SecretKey used by the intention API). If it isn't configured, skip silently
            // — the signed redirect-callback relay (ConfirmPaymentCallbackAsync) is the
            // primary settlement path and needs only the HMAC secret.
            if (string.IsNullOrWhiteSpace(_configuration["Paymob:ApiKey"])) return;
            try
            {
                var authToken = await AuthenticateAsync();
                using var cts = new CancellationTokenSource(TimeSpan.FromMilliseconds(15000));
                var resp = await _httpClient.PostAsJsonAsync(
                    $"{PaymobBaseUrl}/api/ecommerce/orders/transaction_inquiry",
                    new { auth_token = authToken, order_id = orderId }, cts.Token);
                if (!resp.IsSuccessStatusCode)
                {
                    Log.Warning("Paymob transaction_inquiry returned {Status} for order {OrderId}",
                        resp.StatusCode, payment.OrderId);
                    return;
                }

                var obj = await resp.Content.ReadFromJsonAsync<PaymobTransactionDTO>(
                    new JsonSerializerOptions { PropertyNameCaseInsensitive = true }, cts.Token);

                // No transaction on the order yet, or still processing at the gateway:
                // leave Pending so the next poll can settle it.
                if (obj == null || obj.Id == 0 || obj.Pending) return;

                var newStatus = MapTransactionStatus(obj);
                if (newStatus == payment.Status) return;

                payment.Method ??= obj.SourceData?.Type;
                payment.TransactionId = obj.Id.ToString();
                payment.UpdatedAt = DateTime.Now.ToEgyptTime();
                payment.Status = newStatus;
                if (newStatus == PaymentStatus.Captured)
                {
                    payment.CaptureTransactionId = obj.Id.ToString();
                }
                else if (newStatus == PaymentStatus.PreAuthSuccess)
                {
                    payment.PreauthTransactionId = obj.Id.ToString();
                    payment.PreauthExpiresAt ??= DateTime.Now.ToEgyptTime().AddDays(6);
                }

                await _context.SaveChangesAsync();

                var driverId = payment.Trip?.UserTrips?
                    .FirstOrDefault(ut => ut.UserId != payment.UserId && ut.Role == UserTripRole.Driver)?.UserId;
                await NotifyClientAndDriver(payment.UserId, driverId ?? string.Empty, payment.Status);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "ReconcileFromGatewayAsync failed for order {OrderId}", payment.OrderId);
            }
        }

        private static PaymentStatus MapTransactionStatus(PaymobTransactionDTO obj)
        {
            if (obj.IsVoided) return PaymentStatus.Voided;
            if (obj.IsCapture) return obj.Success ? PaymentStatus.Captured : PaymentStatus.CaptureFailed;
            if (obj.IsAuth) return obj.Success ? PaymentStatus.PreAuthSuccess : PaymentStatus.PreAuthFailed;
            return obj.Success ? PaymentStatus.Paid : PaymentStatus.Failed;
        }

        // The client relays Paymob's signed redirect (response) callback after checkout.
        // We validate the HMAC over the same field set as the server-to-server webhook,
        // then settle the payment and notify both sides. This makes online payments work
        // even though the async webhook isn't being delivered, using only the HMAC secret.
        public async Task<Response<string>> ConfirmPaymentCallbackAsync(Dictionary<string, string> query)
        {
            try
            {
                if (query == null || query.Count == 0 || !query.TryGetValue("hmac", out var hmacReceived)
                    || string.IsNullOrEmpty(hmacReceived))
                {
                    return Response<string>.Failure("بيانات الدفع غير مكتملة", 400);
                }

                var secret = _configuration["Paymob:HmacSecret"];
                if (string.IsNullOrEmpty(secret))
                {
                    Log.Error("Paymob:HmacSecret is not configured");
                    return Response<string>.Failure("خطأ في إعدادات الدفع", 500);
                }

                // Paymob's HMAC concatenates these fields in this exact order (same as the
                // webhook); in the redirect they arrive as flat query keys.
                string[] keys =
                {
                    "amount_cents", "created_at", "currency", "error_occured",
                    "has_parent_transaction", "id", "integration_id", "is_3d_secure",
                    "is_auth", "is_capture", "is_refunded", "is_standalone_payment",
                    "is_voided", "order", "owner", "pending",
                    "source_data.pan", "source_data.sub_type", "source_data.type", "success"
                };
                var concatenated = string.Concat(keys.Select(k =>
                    query.TryGetValue(k, out var v) ? v : string.Empty));

                using var hmac = new HMACSHA512(Encoding.UTF8.GetBytes(secret));
                var computedHash = BitConverter.ToString(
                    hmac.ComputeHash(Encoding.UTF8.GetBytes(concatenated))
                ).Replace("-", "").ToLower();

                if (computedHash != hmacReceived.ToLower())
                {
                    return Response<string>.Failure("الطلب غير موثق (HMAC mismatch)", 401);
                }

                var orderId = query.TryGetValue("order", out var o) ? o : null;
                if (string.IsNullOrEmpty(orderId))
                {
                    return Response<string>.Failure("بيانات الدفع غير مكتملة", 400);
                }

                var payment = await _context.Payments
                    .Include(p => p.Trip).ThenInclude(t => t.UserTrips)
                    .FirstOrDefaultAsync(p => p.OrderId == orderId);
                if (payment == null)
                {
                    return Response<string>.Failure("عملية الدفع غير موجودة", 404);
                }

                // Already settled as a success — nothing to do (the webhook may have won).
                if (payment.Status == PaymentStatus.Paid || payment.Status == PaymentStatus.Captured)
                {
                    return Response<string>.Success("ok", "تم تأكيد الدفع مسبقاً", 200);
                }

                bool Flag(string k) => query.TryGetValue(k, out var v)
                    && string.Equals(v, "true", StringComparison.OrdinalIgnoreCase);

                var success = Flag("success");
                var newStatus =
                    Flag("is_voided") ? PaymentStatus.Voided :
                    Flag("is_capture") ? (success ? PaymentStatus.Captured : PaymentStatus.CaptureFailed) :
                    Flag("is_auth") ? (success ? PaymentStatus.PreAuthSuccess : PaymentStatus.PreAuthFailed) :
                    (success ? PaymentStatus.Paid : PaymentStatus.Failed);

                payment.Method ??= query.TryGetValue("source_data.type", out var sd) ? sd : null;
                payment.TransactionId = query.TryGetValue("id", out var id) ? id : payment.TransactionId;
                payment.UpdatedAt = DateTime.Now.ToEgyptTime();
                payment.Status = newStatus;
                if (newStatus == PaymentStatus.Captured)
                {
                    payment.CaptureTransactionId = payment.TransactionId;
                }
                await _context.SaveChangesAsync();

                var driverId = payment.Trip?.UserTrips?
                    .FirstOrDefault(ut => ut.UserId != payment.UserId && ut.Role == UserTripRole.Driver)?.UserId;
                await NotifyClientAndDriver(payment.UserId, driverId ?? string.Empty, payment.Status);

                return Response<string>.Success("ok", "تم تأكيد الدفع", 200);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "ConfirmPaymentCallbackAsync failed");
                return Response<string>.Failure("خطأ أثناء تأكيد الدفع", 500);
            }
        }

        // "Add card" in profile: a small card-verification checkout so the rider can
        // enter + save a card up-front. On success Paymob fires the TOKEN webhook
        // which stores the SavedCard. Not tied to a trip (Payment.TripId = null).
        public async Task<Response<PaymobIntentResponseDTO>> AddCardIntentAsync(string userId)
        {
            using var transaction = await _context.Database.BeginTransactionAsync();
            try
            {
                var user = await _context.Users.FindAsync(userId);
                if (user == null)
                    return Response<PaymobIntentResponseDTO>.Failure("المستخدم غير موجود", 404);

                var verifyAmount = int.TryParse(_configuration["Paymob:CardVerificationAmount"], out var v) && v > 0
                    ? v
                    : 1; // EGP

                var payment = new Payment
                {
                    UserId = userId,
                    TripId = null,
                    Amount = verifyAmount,
                    Currency = "EGP",
                    CreatedAt = DateTime.Now.ToEgyptTime(),
                    Status = PaymentStatus.Pending,
                    Method = "CardVerification",
                };
                _context.Payments.Add(payment);

                var body = new Dictionary<string, object?>
                {
                    ["amount"] = verifyAmount * 100,
                    ["currency"] = "EGP",
                    ["merchant_order_id"] = payment.Id,
                    // Card only (no wallet) and no saved-card tokens, so the rider
                    // enters a NEW card and can tick "save".
                    ["payment_methods"] = new[]
                    {
                        int.Parse(_configuration["Paymob:CardIntegrationId"] ?? "0")
                    },
                    ["billing_data"] = new
                    {
                        first_name = user.FullName,
                        last_name = "NA",
                        phone_number = user.PhoneNumber,
                        email = user.Email,
                    }
                };

                using var requestMessage = new HttpRequestMessage(HttpMethod.Post,
                    $"{PaymobBaseUrl}/v1/intention/");
                requestMessage.Headers.Authorization =
                    new System.Net.Http.Headers.AuthenticationHeaderValue("Token", _configuration["Paymob:SecretKey"]);
                requestMessage.Content = JsonContent.Create(body);

                using var cts = new CancellationTokenSource(TimeSpan.FromMilliseconds(15000));
                var response = await _httpClient.SendAsync(requestMessage, cts.Token);
                response.EnsureSuccessStatusCode();
                var intentResponse = await response.Content.ReadFromJsonAsync<PaymobIntentResponseDTO>(cancellationToken: cts.Token);
                if (intentResponse == null)
                    return Response<PaymobIntentResponseDTO>.Failure("فشل في بدء إضافة البطاقة", 400);

                payment.OrderId = intentResponse.IntentionOrderId.ToString();
                await _context.SaveChangesAsync();
                intentResponse.PublicKey = _configuration["Paymob:PublicKey"];
                await transaction.CommitAsync();
                return Response<PaymobIntentResponseDTO>.Success(intentResponse, "تابع لإضافة البطاقة", 200);
            }
            catch (HttpRequestException httpEx)
            {
                await transaction.RollbackAsync();
                Log.Error(httpEx, "AddCardIntent HTTP error");
                return Response<PaymobIntentResponseDTO>.Failure("تعذّر الاتصال بخدمة الدفع. حاول لاحقاً.", 503);
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync();
                Log.Error(ex, "AddCardIntent error");
                return Response<PaymobIntentResponseDTO>.Failure("حدث خطأ أثناء إضافة البطاقة", 500);
            }
        }

        public async Task<Response<List<SavedCardDTO>>> GetSavedCardsAsync(string userId)
        {
            try
            {
                var cards = await _context.SavedCards
                    .Where(c => c.UserId == userId && c.IsActive)
                    .OrderByDescending(c => c.CreatedAt)
                    .Select(c => new SavedCardDTO
                    {
                        Id = c.Id,
                        MaskedPan = c.MaskedPan,
                        CreatedAt = c.CreatedAt,
                    })
                    .ToListAsync();
                return Response<List<SavedCardDTO>>.Success(cards, "تم جلب البطاقات المحفوظة", 200);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "GetSavedCards error for user {UserId}", userId);
                return Response<List<SavedCardDTO>>.Failure("حدث خطأ أثناء جلب البطاقات", 500);
            }
        }

        public async Task<Response<string>> DeleteSavedCardAsync(string userId, int cardId)
        {
            try
            {
                var card = await _context.SavedCards
                    .FirstOrDefaultAsync(c => c.Id == cardId && c.UserId == userId);
                if (card == null)
                    return Response<string>.Failure("البطاقة غير موجودة", 404);
                // Soft-delete so the token is no longer offered at checkout.
                card.IsActive = false;
                await _context.SaveChangesAsync();
                return Response<string>.Success("تم حذف البطاقة", "تم حذف البطاقة", 200);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "DeleteSavedCard error card {CardId}", cardId);
                return Response<string>.Failure("حدث خطأ أثناء حذف البطاقة", 500);
            }
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

        // Driver-confirmed cash: marks the trip Paid (Cash) on behalf of the
        // trip's client. Returns the client id in Data so the hub can notify
        // the correct user group (the rider waiting on its completion screen).
        public async Task<Response<string>> ConfirmCashPaymentByDriverAsync(string tripId)
        {
            try
            {
                var trip = await _context.Trips
                    .Include(t => t.Payment)
                    .Include(t => t.UserTrips)
                    .FirstOrDefaultAsync(t => t.Id == tripId);
                if (trip == null)
                {
                    return Response<string>.Failure("الرحلة غير موجودة", 404);
                }
                var clientId = trip.UserTrips
                    .FirstOrDefault(ut => ut.Role == UserTripRole.Client)?.UserId;
                if (string.IsNullOrEmpty(clientId))
                {
                    return Response<string>.Failure("لم يتم العثور على عميل لهذه الرحلة", 404);
                }
                if (trip.Payment.Any(p => p.Status == PaymentStatus.Paid))
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
                    UserId = clientId,
                    TripId = tripId
                };
                _context.Payments.Add(payment);
                await _context.SaveChangesAsync();
                return Response<string>.Success(clientId, "تم تأكيد استلام الدفع نقدًا", 200);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "PaymentService confirm cash payment error");
                return Response<string>.Failure("حدث خطأ أثناء تأكيد الدفع نقدا", "حدث خطأ أثناء تأكيد الدفع نقدا", 500);
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
                Message = status switch
                {
                    PaymentStatus.Paid or PaymentStatus.Captured => "تم دفع الرحلة بنجاح",
                    PaymentStatus.PreAuthSuccess => "تم حجز مبلغ الرحلة بنجاح، يمكن بدء الرحلة",
                    PaymentStatus.PreAuthFailed => "تم رفض البطاقة، يرجى استخدام بطاقة أخرى أو الدفع نقداً",
                    _ => "فشل في عملية الدفع"
                }
            };

            await _tripHub.Clients.Group(HubGroups.User(userId))
                .SendAsync(HubEvents.TripPaymentUpdated, response);
            if (!string.IsNullOrEmpty(driverId))
            {
                await _tripHub.Clients.Group(HubGroups.Driver(driverId))
                    .SendAsync(HubEvents.TripPaymentUpdated, response);
            }

            // Push notifications: confirm the online payment to both sides. Only on actual
            // money movement (Paid / Captured) — a pre-auth hold isn't a charge yet.
            if (status is PaymentStatus.Paid or PaymentStatus.Captured)
            {
                try
                {
                    await _notificationService.SendNotificationToUserAsync(
                        userId,
                        "تم الدفع 🎉",
                        "تم استلام دفعتك عبر فيزا بنجاح. شكرًا لاختيارك V-Go!",
                        new Dictionary<string, string> { { "type", "payment_done" } });
                    if (!string.IsNullOrEmpty(driverId))
                    {
                        await _notificationService.SendNotificationToUserAsync(
                            driverId,
                            "تم تأكيد الدفع",
                            "أكمل العميل الدفع عبر فيزا بنجاح.",
                            new Dictionary<string, string> { { "type", "payment_done" } });
                    }
                }
                catch (Exception ex)
                {
                    Log.Error(ex, "Failed sending payment-done push notifications");
                }
            }

            if (status is PaymentStatus.Paid or PaymentStatus.Captured or PaymentStatus.PreAuthSuccess)
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
