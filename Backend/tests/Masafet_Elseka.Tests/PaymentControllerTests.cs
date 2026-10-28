using System.Security.Claims;
using Masafet_Elseka.Application.DTOs.DriverFinance;
using Masafet_Elseka.Application.DTOs.Payment;
using Masafet_Elseka.Application.DTOs.Payment.PayMob;
using Masafet_Elseka.Application.Interfaces.IPaymentService;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Data;
using Masafet_Elseka.Presentation.Controllers;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Masafet_Elseka.Tests;

public class PaymentControllerTests
{
    [Theory]
    [InlineData(true, "other-driver", UserTripRole.Driver, TripStatus.Completed, 403)]
    [InlineData(true, "assigned", UserTripRole.Driver, TripStatus.Pending, 400)]
    [InlineData(true, "assigned", UserTripRole.Driver, TripStatus.Canceled, 400)]
    [InlineData(true, "assigned", UserTripRole.Client, TripStatus.Completed, 403)]
    [InlineData(false, "other-client", UserTripRole.Client, TripStatus.Canceled, 403)]
    [InlineData(false, "assigned", UserTripRole.Client, TripStatus.Pending, 400)]
    [InlineData(false, "assigned", UserTripRole.Driver, TripStatus.Canceled, 403)]
    [InlineData(true, null, UserTripRole.Driver, TripStatus.Completed, 403)]
    [InlineData(false, null, UserTripRole.Client, TripStatus.Canceled, 403)]
    public async Task Unauthorized_or_invalid_state_does_not_call_payment_service(
        bool capture, string? caller, UserTripRole membership, TripStatus status, int expected)
    {
        using var db = NewDb();
        await SeedTrip(db, membership, status);
        var payments = new FakePayments();
        var controller = Controller(db, payments, caller, capture ? "Driver" : "Client");

        var result = capture ? await controller.Capture("trip") : await controller.Void("trip");

        Assert.Equal(expected, Assert.IsAssignableFrom<ObjectResult>(result).StatusCode);
        Assert.Empty(payments.Calls);
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task Missing_trip_returns_404(bool capture)
    {
        using var db = NewDb();
        var payments = new FakePayments();
        var controller = Controller(db, payments, "assigned", capture ? "Driver" : "Client");

        var result = capture ? await controller.Capture("missing") : await controller.Void("missing");

        Assert.IsType<NotFoundObjectResult>(result);
        Assert.Empty(payments.Calls);
    }

    [Theory]
    [InlineData(true, UserTripRole.Driver, TripStatus.Completed)]
    [InlineData(false, UserTripRole.Client, TripStatus.Canceled)]
    [InlineData(false, UserTripRole.Client, TripStatus.Rejected)]
    public async Task Assigned_user_in_allowed_state_calls_service(
        bool capture, UserTripRole membership, TripStatus status)
    {
        using var db = NewDb();
        await SeedTrip(db, membership, status);
        var payments = new FakePayments();
        var controller = Controller(db, payments, "assigned", capture ? "Driver" : "Client");

        var result = capture ? await controller.Capture("trip") : await controller.Void("trip");

        Assert.Equal(200, Assert.IsType<ObjectResult>(result).StatusCode);
        Assert.Equal(new[] { (capture ? "capture" : "void", "trip") }, payments.Calls);
    }

    [Theory]
    [InlineData(true, true)]
    [InlineData(false, true)]
    [InlineData(true, false)]
    [InlineData(false, false)]
    public async Task Admin_bypasses_membership_state_and_existence_checks(bool capture, bool exists)
    {
        using var db = NewDb();
        if (exists)
            await SeedTrip(db, UserTripRole.Client, TripStatus.Pending);
        var payments = new FakePayments();
        var controller = Controller(db, payments, "admin", "Admin");

        var result = capture ? await controller.Capture("trip") : await controller.Void("trip");

        Assert.Equal(200, Assert.IsType<ObjectResult>(result).StatusCode);
        Assert.Equal(new[] { (capture ? "capture" : "void", "trip") }, payments.Calls);
    }

    private static Context NewDb() => new(new DbContextOptionsBuilder<Context>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);

    private static async Task SeedTrip(Context db, UserTripRole membership, TripStatus status)
    {
        db.Trips.Add(new Trip
        {
            Id = "trip", Status = status, RowVersion = Array.Empty<byte>(),
            UserTrips = new List<UserTrip>
            {
                new() { Id = "membership", TripId = "trip", UserId = "assigned", Role = membership }
            }
        });
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();
    }

    private static PaymentController Controller(Context db, FakePayments payments, string? userId, string role)
    {
        var claims = new List<Claim> { new(ClaimTypes.Role, role) };
        if (userId != null)
            claims.Add(new Claim(ClaimTypes.NameIdentifier, userId));
        return new PaymentController(payments, db)
        {
            ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext
                {
                    User = new ClaimsPrincipal(new ClaimsIdentity(claims, "test"))
                }
            }
        };
    }

    private sealed class FakePayments : IPaymentService
    {
        public List<(string Action, string TripId)> Calls { get; } = new();

        public Task<Response<Payment>> CaptureRidePaymentAsync(string tripId)
        {
            Calls.Add(("capture", tripId));
            return Task.FromResult(Response<Payment>.Success(new Payment()));
        }

        public Task<Response<Payment>> VoidRidePaymentAsync(string tripId)
        {
            Calls.Add(("void", tripId));
            return Task.FromResult(Response<Payment>.Success(new Payment()));
        }

        public Task<Response<PaymobIntentResponseDTO>> CreatePaymentIntentAsync(PaymentRequestDTO request) => throw new NotImplementedException();
        public Task<Response<PaymobIntentResponseDTO>> InitiatePreAuthAsync(PaymentRequestDTO request) => throw new NotImplementedException();
        public Task<int> VoidExpiredPreAuthsAsync() => throw new NotImplementedException();
        public Task<Response<string>> HandleTransactionWebhookAsync(PaymobWebhookDTO webhook, string hmac) => throw new NotImplementedException();
        public Task<Response<string>> HandleTokenWebhookAsync(PaymobCardTokenDTO webhook, string hmac) => throw new NotImplementedException();
        public Task<Response<Payment>> GetPaymentStatusAsync(string tripId) => throw new NotImplementedException();
        public Task<Response<string>> ConfirmPaymentCallbackAsync(Dictionary<string, string> query) => throw new NotImplementedException();
        public Task<Response<List<SavedCardDTO>>> GetSavedCardsAsync(string userId) => throw new NotImplementedException();
        public Task<Response<string>> DeleteSavedCardAsync(string userId, int cardId) => throw new NotImplementedException();
        public Task<Response<PaymobIntentResponseDTO>> AddCardIntentAsync(string userId) => throw new NotImplementedException();
        public Task<Response<string>> PayTripInCashAsync(string tripId, string userId) => throw new NotImplementedException();
        public Task<Response<string>> ConfirmCashPaymentByDriverAsync(string tripId) => throw new NotImplementedException();
        public Task<Response<string>> MarkPaymentRefusedByDriverAsync(string tripId, string driverId) => throw new NotImplementedException();
        public Task<Response<SettlementIntentDTO>> CreateDriverSettlementIntentAsync(string driverId) => throw new NotImplementedException();
        public Task RefreshSettlementAsync(string paymentId, string driverId) => throw new NotImplementedException();
    }
}
