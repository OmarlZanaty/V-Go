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

        // Visa pre-authorization (Auth & Capture). InitiatePreAuth creates a hold
        // intention (returns the same unified-checkout payload Flutter already uses);
        // Capture charges the held amount on ride completion; Void releases it on
        // cancellation. VoidExpiredPreAuths is the cron sweep for stale holds.
        Task<Response<PaymobIntentResponseDTO>> InitiatePreAuthAsync(PaymentRequestDTO request);
        Task<Response<Payment>> CaptureRidePaymentAsync(string tripId);
        Task<Response<Payment>> VoidRidePaymentAsync(string tripId);
        Task<int> VoidExpiredPreAuthsAsync();
        Task<Response<string>> HandleTransactionWebhookAsync(PaymobWebhookDTO webhook /*PaymobTransactionDTO webhook*/, string hmac);
        Task<Response<string>> HandleTokenWebhookAsync(PaymobCardTokenDTO webhook, string hmac);
        Task<Response<Payment>> GetPaymentStatusAsync(string tripId);
        // The client relays Paymob's signed redirect callback here after checkout, so a
        // card payment settles (and the captain is notified) without depending on the
        // async server-to-server webhook. Validated with the configured HMAC secret.
        Task<Response<string>> ConfirmPaymentCallbackAsync(Dictionary<string, string> query);
        // Saved cards (card-on-file): list the user's active saved cards and delete one.
        Task<Response<List<SavedCardDTO>>> GetSavedCardsAsync(string userId);
        Task<Response<string>> DeleteSavedCardAsync(string userId, int cardId);
        // "Add card" verification checkout (returns the unified-checkout payload).
        Task<Response<PaymobIntentResponseDTO>> AddCardIntentAsync(string userId);
        Task<Response<string>> PayTripInCashAsync(string tripId, string userId);
        // Driver confirms they received the cash. Marks the trip paid on behalf
        // of the trip's client and returns that client id (so the hub can
        // notify the right user). Used by the captain's "payment received" action.
        Task<Response<string>> ConfirmCashPaymentByDriverAsync(string tripId);
    }
}
