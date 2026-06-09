using Masafet_Elseka.Application.DTOs.Client;
using Masafet_Elseka.Application.DTOs.Driver;
using Masafet_Elseka.Application.DTOs.Trip;
using Masafet_Elseka.Application.DTOs.User;
using Masafet_Elseka.Application.DTOs.UserTripDTO;
using Masafet_Elseka.Application.ExternalInterfaces.ICachService;
using Masafet_Elseka.Application.Helpers;
using Masafet_Elseka.Application.Interfaces.IDriverService;
using Masafet_Elseka.Application.Interfaces.INotificationService;
using Masafet_Elseka.Application.Interfaces.IPaymentService;
using Masafet_Elseka.Application.Interfaces.IRatingService;
using Masafet_Elseka.Application.Interfaces.ITripService;
using Masafet_Elseka.Application.Interfaces.IUserTripService;
using Masafet_Elseka.Application.Interfaces.User;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Const;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Data;
using Masafet_Elseka.Infrastructure.Hubs.HubHelper;
using Masafet_Elseka.Infrastructure.UOW;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Serilog;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Hubs
{
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    public class TripHub : Hub
    {
        private readonly ITripService _tripService;
        private readonly IUserTripService _userTripService;
        private readonly IUnitOfWork _unitOfWork;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly IDriverService _driverService;
        private readonly Context _context;
        private readonly IUserService _userService;
        private readonly IRatingService _ratingService;
        private double _distanceThresholdKm = 800.0;
        private readonly ILogger<TripHub> _logger;
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly INotificationService _notificationService;
        private readonly IPaymentService _paymentService;

        public TripHub(ITripService tripService, IUserTripService userTripService, IUnitOfWork unitOfWork, UserManager<ApplicationUser> userManage,
            IDriverService driverService, Context context, IUserService userService, IRatingService ratingService, ILogger<TripHub> logger,
            IServiceScopeFactory scopeFactory, INotificationService notificationService, IPaymentService paymentService)
        {
            _tripService = tripService;
            _userTripService = userTripService;
            _unitOfWork = unitOfWork;
            _userManager = userManage;
            _driverService = driverService;
            _context = context;
            _userService = userService;
            _ratingService = ratingService;
            _logger = logger;
            _scopeFactory = scopeFactory;
            _notificationService = notificationService;
            _paymentService = paymentService;
        }
        public override async Task OnConnectedAsync()
        {
            var userId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            var roleString = Context.User?.FindFirst(ClaimTypes.Role)?.Value;

            if (!string.IsNullOrEmpty(userId))
            {
                await Groups.AddToGroupAsync(Context.ConnectionId, HubGroups.User(userId));

                if (roleString == "Driver")
                {
                    await Groups.AddToGroupAsync(Context.ConnectionId, HubGroups.Driver(userId));
                    await Groups.AddToGroupAsync(Context.ConnectionId, HubGroups.Drivers);
                }

                if (roleString == "Admin")
                {
                    await Groups.AddToGroupAsync(Context.ConnectionId, HubGroups.Admin);
                }

                if (Enum.TryParse<UserTripRole>(roleString, out var role))
                {
                    await SendCurrentTrip(userId, role);
                }
            }
            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var userId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            var role = Context.User?.FindFirst(ClaimTypes.Role)?.Value;

            if (!string.IsNullOrEmpty(userId))
            { 
                await Groups.RemoveFromGroupAsync(Context.ConnectionId, HubGroups.User(userId));

                if (role == "Driver")
                {
                    await Groups.RemoveFromGroupAsync(Context.ConnectionId, HubGroups.Driver(userId));
                    await Groups.RemoveFromGroupAsync(Context.ConnectionId, HubGroups.Drivers);
                }

                if (role == "Admin")
                {
                    await Groups.RemoveFromGroupAsync(Context.ConnectionId, HubGroups.Admin);
                }
            }

            _logger.LogError("\nSignalR disconnected: " + exception?.Message+"\n");
            await base.OnDisconnectedAsync(exception);
        }


        public async Task<Response<TripResponseDTO>> RequestTrip(TripRequest request)
        {
            try
            {
                if (request == null)
                {
                    return Response<TripResponseDTO>.Failure("هذا الطلب غير صالح", 400);
                }

                var userResult = await _userService.GetByIdAsync(request.UserId);
                if (!userResult.IsSuccess)
                {
                    return Response<TripResponseDTO>.Failure("المستخدم غير موجود", 404);
                }

                bool hasActiveTrip = await _unitOfWork.Trips.AnyAsync(t =>
                    t.UserTrips.Any(ut => ut.UserId == request.UserId &&
                        (t.Status == TripStatus.Pending || t.Status == TripStatus.InProgress)));

                if (hasActiveTrip)
                {
                    var roles = await _userManager.GetRolesAsync(new ApplicationUser { Id = request.UserId });
                    if(!roles.Contains("Admin") && !roles.Contains("Dispatcher"))
                    {
                        return Response<TripResponseDTO>.Failure("المستخدم لديه رحلة جارية بالفعل", 400);
                    }
                }

                var createTrip = await _tripService.AddTrip(request);
                if (!createTrip.IsSuccess)
                {
                    return Response<TripResponseDTO>.Failure(createTrip.Message, createTrip.StatusCode, createTrip.Errors);
                }

                var trip = createTrip.Data;
                trip.ClientId = userResult.Data.Id;
                trip.ClientName = userResult.Data.Name;
                trip.ClientGender = userResult.Data.Gender;
                trip.ClientPhone = userResult.Data.PhoneNumber;
                trip.ClientProfilePicture = userResult.Data.ProfilePicture;
                await _tripService.SetTripToCache(trip);

                var assignClient = await _userTripService.AssignUserToTrip(new UserTripDTO
                {
                    TripId = trip.Id,
                    UserId = request.UserId,
                    Role = UserTripRole.Client
                });

                if (!assignClient.IsSuccess)
                {
                    return Response<TripResponseDTO>.Failure(assignClient.Message, assignClient.StatusCode, assignClient.Errors);
                }

                try
                {
                    //  Notify available drivers
                    await NotifyAvailableDrivers(request, trip, userResult.Data);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error notifying available drivers for trip {TripId}", trip.Id);
                }
                try
                {
                    // Await so failures are actually observed/logged. With the previous
                    // fire-and-forget (_ = ...), exceptions thrown after the first await were
                    // discarded and the surrounding catch never ran.
                    await SendCurrentTripInScope(trip.ClientId ?? request.UserId, UserTripRole.Client);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error sending current trip for user {UserId}", trip.ClientId ?? request.UserId);
                }

                return Response<TripResponseDTO>.Success(trip, "تم طلب الرحلة بنجاح", 201);
            }
            catch (Exception ex)
            {
                return Response<TripResponseDTO>.Failure(new TripResponseDTO(), "حدث خطأ غير متوقع، يرجى المحاولة لاحقًا", 500);
            }
        }

        public async Task<Response<string>> ApproveAndAssignDriverToTrip(string tripId, string driverId,string latitude, string longitude)
        {
            using var transaction = await _context.Database.BeginTransactionAsync();
            try
            {
                var trip = await _unitOfWork.Trips.GetByIdAsync(tripId);

                if (trip == null || trip.Status != TripStatus.Pending)
                    return Response<string>.Failure("الرحلة غير موجودة أو ليست في حالة انتظار", 404);

                var driver = await _context.Users.Include(u => u.Scooter)
                    .FirstOrDefaultAsync(u => u.Id == driverId);
                if (driver == null || !await _userManager.IsInRoleAsync(driver, "Driver"))
                    return Response<string>.Failure("السائق غير موجود", 404);

                if (driver.IsAvailable==false)
                    return Response<string>.Failure("السائق غير متاح حالياً", 400);

                trip.Status = TripStatus.Accepted;

                var clientInTrip = await _context.UserTrips
                    .Include(u => u.User)
                    .FirstOrDefaultAsync(ut => ut.TripId == tripId && ut.Role == UserTripRole.Client);

                if (clientInTrip == null)
                    return Response<string>.Failure("لم يتم العثور على العميل في الرحلة", 404);

                var assignDriverToTrip = await _userTripService.AssignUserToTrip(new UserTripDTO
                {
                    TripId = trip.Id,
                    UserId = driverId,
                    Role = UserTripRole.Driver,
                });

                if (!assignDriverToTrip.IsSuccess)
                    return Response<string>.Failure(assignDriverToTrip.Message, assignDriverToTrip.StatusCode, assignDriverToTrip.Errors);

                var userTrip = await _context.UserTrips.Where(t => t.TripId == tripId).ToListAsync();
                userTrip.ForEach(ut => ut.IsApproved = true);

                await _driverService.UpdateAvailability(driverId, false);
                await _driverService.SetDriverStatusToCache(new DriverStatusDTO
                {
                    DriverId = driver.Id,
                    IsAvailable = false,
                });

                try
                {
                    await _unitOfWork.SaveAsync(); 
                   await transaction.CommitAsync();
                }
                catch (DbUpdateConcurrencyException)
                {
                   await transaction.RollbackAsync();
                    return Response<string>.Failure("تم قبول الرحلة من قبل سائق آخر بالفعل", 409);
                }

                await NotifyClientTripApproved(clientInTrip.UserId, trip, driver,latitude?? "30.0444", longitude?? "31.2357");
                await NotifyAdminTripApproved(clientInTrip, trip, driver);
                await SendCurrentTrip(clientInTrip.UserId, UserTripRole.Client);
                await NotifyOtherDriversTripTaken(tripId, driverId, clientInTrip.User.Gender);
                await _tripService.UpdateTripStateInCache(trip.Id, TripStatus.Accepted);
                return Response<string>.Success("تم قبول الرحلة وتعيين السائق بنجاح", "تم قبول الرحلة وتعيين السائق بنجاح", 200);
            }
            catch (Exception ex)
            {
             await transaction.RollbackAsync();
                return Response<string>.Failure("حدث خطأ أثناء محاولة قبول الرحلة", "حدث خطأ غير متوقع، يرجى المحاولة لاحقًا", 500);
            }
        }
        public async Task SendCurrentTrip(string userId, UserTripRole role)
        {
            var response = await _tripService.GetCurrentTrip(userId, role);

            if (!response.IsSuccess || response.Data == null)
            {
                await Clients.Caller.SendAsync(HubEvents.ReceiveCurrentTripError, response.Message);
                return;
            }

            var trip = response.Data;
          
            if (!string.IsNullOrEmpty(trip.UserId))
            {
                await  Clients.Group(HubGroups.User(trip.UserId))
                         .SendAsync(HubEvents.ReceiveCurrentTrip, trip);
            }
            if (!string.IsNullOrEmpty(trip.DriverId) && trip.DriverName != "لم يتم تحديد سائق حتى الان")
            {
                await Clients.Group(HubGroups.Driver(trip.DriverId))
                        .SendAsync(HubEvents.ReceiveCurrentTrip, trip);
            }

        }

        private async Task SendCurrentTripInScope(string userId, UserTripRole role)
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                // Resolve services from the new scope (avoid using Hub instance members here)
                var tripServiceObj = scope.ServiceProvider.GetService(typeof(ITripService));
                var hubContextObj = scope.ServiceProvider.GetService(typeof(IHubContext<TripHub>));

                var tripService = tripServiceObj as ITripService;
                var hubContext = hubContextObj as IHubContext<TripHub>;

                if (tripService == null || hubContext == null)
                {
                    _logger?.LogError("Unable to resolve ITripService or IHubContext<TripHub> in SendCurrentTripInScope.");
                    return;
                }

                var response = await tripService.GetCurrentTrip(userId, role);
                if (!response.IsSuccess || response.Data == null)
                {
                    return;
                }

                var trip = response.Data;

                if (!string.IsNullOrEmpty(trip.UserId))
                {
                    await hubContext.Clients.Group(HubGroups.User(trip.UserId))
                        .SendAsync(HubEvents.ReceiveCurrentTrip, trip);
                }

                if (!string.IsNullOrEmpty(trip.DriverId) && trip.DriverName != "لم يتم تحديد سائق حتى الان")
                {
                    await hubContext.Clients.Group(HubGroups.Driver(trip.DriverId))
                        .SendAsync(HubEvents.ReceiveCurrentTrip, trip);
                }
            }
            catch (Exception ex)
            {
                _logger?.LogError(ex, "SendCurrentTripInScope failed for user {UserId}", userId);
            }
        }

        public async Task<Response<object>> Arrived(string tripId, string driverId)
        {
            try
            {
                //var driverId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;

                var existingDriverInTrip = await _unitOfWork.UserTrips
                    .GetByExpressionAsync(us => us.UserId == driverId && us.TripId == tripId && us.Role == UserTripRole.Driver);

                if (existingDriverInTrip == null)
                {
                    return Response<object>.Failure("السائق غير معين لهذه الرحلة", 404);
                }

                var result = await _tripService.ArrivedToTrip(tripId);
                if (!result.IsSuccess)
                {
                    return Response<object>.Failure(result.Message, result.StatusCode, result.Errors);
                }
                var clientId= result.Data.CLientId;
                await NotifyClientTripArrived(result.Data.CLientId, tripId);
                await NotifyDriverTripArrived(driverId, tripId);
                await _tripService.UpdateTripStateInCache(tripId, TripStatus.Arrived);
                return Response<object>.Success(result.Data, result.Message, result.StatusCode);
            }
            catch (Exception ex)
            {
                return Response<object>.Failure("حدث خطأ أثناء محاولة بدء الرحلة", "حدث خطأ غير متوقع، يرجى المحاولة لاحقًا", 500);
            }
        }

        public async Task<Response<object>> StartTrip(string tripId, string driverId)
        {
            try
            {
                var existingDriverInTrip = await _unitOfWork.UserTrips
                    .GetByExpressionAsync(us => us.UserId == driverId && us.TripId == tripId && us.Role == UserTripRole.Driver);

                if (existingDriverInTrip == null)
                {
                    return Response<object>.Failure("السائق غير معين لهذه الرحلة", 404);
                }

                var result = await _tripService.StartTrip(tripId);
                if (!result.IsSuccess)
                {
                    return Response<object>.Failure(result.Message, result.StatusCode, result.Errors);
                }

                await NotifyClientTripStarted(result.Data.CLientId, tripId);
                await NotifyDriverTripStarted(driverId, tripId);
                await _tripService.UpdateTripStateInCache(tripId, TripStatus.InProgress);

                // Visa trips: the client pays online once the ride starts. Prompt
                // the client to pay and tell the captain payment is pending.
                if (string.Equals(result.Data.PaymentMethod, "Visa", StringComparison.OrdinalIgnoreCase))
                {
                    var data = new Dictionary<string, string>
                    {
                        { "type", "visa_payment_due" },
                        { "tripId", tripId },
                    };
                    await _notificationService.SendNotificationToUserAsync(
                        result.Data.CLientId,
                        "إتمام الدفع",
                        "بدأت رحلتك — يرجى إتمام الدفع عبر فيزا.",
                        data);
                    await _notificationService.SendNotificationToUserAsync(
                        driverId,
                        "بانتظار دفع العميل",
                        "دفع العميل عبر فيزا قيد الانتظار، يرجى تذكيره بإتمام الدفع.",
                        new Dictionary<string, string>
                        {
                            { "type", "visa_payment_pending" },
                            { "tripId", tripId },
                        });
                }
                return Response<object>.Success(result.Data, result.Message, result.StatusCode);
            }
            catch (Exception ex)
            {
                return Response<object>.Failure("حدث خطأ أثناء محاولة بدء الرحلة", "حدث خطأ غير متوقع، يرجى المحاولة لاحقًا", 500);
            }
        }

        public async Task<Response<object>> EndTrip(string tripId, string driverId)
        {
            try
            {
                var existingDriverInTrip = await _unitOfWork.UserTrips
                    .GetByExpressionAsync(us => us.UserId == driverId && us.TripId == tripId && us.Role == UserTripRole.Driver);

                if (existingDriverInTrip == null)
                {
                    return Response<object>.Failure("السائق غير معين لهذه الرحلة", 404);
                }

                var result = await _tripService.EndTrip(tripId);
                if (!result.IsSuccess)
                {
                    return Response<object>.Failure(result.Message, result.StatusCode, result.Errors);
                }

                await NotifyClientTripEnded(result.Data.CLientId, tripId);
                await NotifyDriverTripEnded(driverId, tripId);
                await _tripService.UpdateTripStateInCache(tripId, TripStatus.Completed);

                // Visa pre-auth: capture the held amount now the ride is complete.
                // No-op for cash / non-pre-auth trips (returns without charging).
                try { await _paymentService.CaptureRidePaymentAsync(tripId); }
                catch (Exception capEx) { Log.Error(capEx, "Capture after EndTrip failed for trip {TripId}", tripId); }

                return Response<object>.Success(result.Data, result.Message, result.StatusCode);
            }
            catch (Exception ex)
            {
                return Response<object>.Failure("حدث خطأ أثناء محاولة إنهاء الرحلة", "حدث خطأ غير متوقع، يرجى المحاولة لاحقًا", 500);
            }
        }

        public async Task<Response<string>> RejectTrip(string tripId)
        {
            try
            {
                var trip = await _unitOfWork.Trips.GetByIdAsync(tripId);
                if (trip == null)
                {
                    return Response<string>.Failure("الرحلة غير موجودة أو ليست في حالة انتظار", 404);
                }
                trip.Status = TripStatus.Rejected;
                // May be null if the trip is rejected moments after creation, before the
                // client UserTrip link is persisted — guard against a NullReferenceException.
                var userTrip = await _context.UserTrips
                    .FirstOrDefaultAsync(t => t.TripId == tripId && t.Role == UserTripRole.Client);
                if (userTrip != null)
                {
                    userTrip.IsApproved = false;
                }
                await _unitOfWork.SaveAsync();
                if (userTrip != null)
                {
                    await Clients.Group($"User_{userTrip.UserId}").SendAsync("TripRejected", new
                    {
                        TripId = trip.Id,
                        UserId = userTrip.UserId,
                        Status = trip.Status,
                        UpdatedAt = DateTime.Now.ToEgyptTime()
                    });
                }
                await _tripService.UpdateTripStateInCache(trip.Id, TripStatus.Rejected);
                return Response<string>.Success("تم رفض الرحلة بنجاح", "تم رفض الرحلة بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<string>.Failure("حدث خطأ أثناء محاولة رفض الرحلة", "حدث خطأ غير متوقع، يرجى المحاولة لاحقًا", 500);
            }
        }

        public async Task<Response<object>> CancelTripRequest(string tripId, string userId)
        {
            try
            {
                if (string.IsNullOrEmpty(tripId) || string.IsNullOrEmpty(userId))
                    return Response<object>.Failure("معرف الرحلة أو معرف المستخدم غير صالح", 400);

                var isAcceptedTrip = await IsAcceptedTrip(tripId);
                var result = await _tripService.CancelTrip(tripId, userId);
                if (!result.IsSuccess)
                    return Response<object>.Failure(result.Message, result.StatusCode, result.Errors);

                if (isAcceptedTrip)
                    await NotifyDriverTripCancelled(tripId, userId);
                else
                    await NotifyAvailableDriversTripCancelled(tripId, userId,result.Data);

                await NotifyAdminTripCancelled(tripId, userId);
                await NotifyClientTripCancelled(tripId, userId);
                await _tripService.UpdateTripStateInCache(tripId, TripStatus.Canceled);

                // Visa pre-auth: release the hold on cancellation (no-op otherwise).
                try { await _paymentService.VoidRidePaymentAsync(tripId); }
                catch (Exception voidEx) { Log.Error(voidEx, "Void after CancelTrip failed for trip {TripId}", tripId); }

                return Response<object>.Success(result.Message, result.Message, 200);
            }
            catch (Exception ex)
            {
                return Response<object>.Failure("حدث خطأ أثناء محاولة إلغاء طلب الرحلة", "حدث خطأ غير متوقع، يرجى المحاولة لاحقًا", 500);
            }
        }

        public async Task PayTripInCash(string tripId, string driverId)
        {
            try
            {
                var userId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;

                var result = await _paymentService.PayTripInCashAsync(tripId, userId!);
                if (!result.IsSuccess)
                {
                    return;
                }
                await NotifyPaymentForDriverAndClient(userId!, driverId);
                await SendCurrentTripInScope(userId!, UserTripRole.Client);
                return;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in PayTripInCash for trip {TripId}", tripId);
            }
        }

        // Driver presses "payment received" for a cash trip. Marks the trip paid
        // and notifies both the rider (so its locked completion screen unlocks)
        // and the driver.
        public async Task<Response<object>> ConfirmCashPayment(string tripId)
        {
            try
            {
                var driverId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
                if (string.IsNullOrEmpty(tripId))
                    return Response<object>.Failure("معرف الرحلة غير صالح", 400);

                var result = await _paymentService.ConfirmCashPaymentByDriverAsync(tripId);
                if (!result.IsSuccess)
                    return Response<object>.Failure(result.Message, result.StatusCode, result.Errors);

                var clientId = result.Data; // returned by the service
                await NotifyPaymentForDriverAndClient(clientId!, driverId!);
                await SendCurrentTripInScope(clientId!, UserTripRole.Client);
                return Response<object>.Success(result.Message, result.Message, 200);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in ConfirmCashPayment for trip {TripId}", tripId);
                return Response<object>.Failure("حدث خطأ أثناء تأكيد الدفع", "حدث خطأ غير متوقع، يرجى المحاولة لاحقًا", 500);
            }
        }

        // Private Helper Functions "Events"
        #region Helpers

        #region Notify Avilable Drivers Event
        private async Task NotifyAvailableDrivers(TripRequest request, TripResponseDTO trip, UserDTO client)
        {
            var drivers = await _driverService.GetAvailableDriversFromCache(client.Gender);
            var availableDrivers = new List<DriverStatusDTO>();

            if (!drivers.IsSuccess || drivers.Data == null || !drivers.Data.Any())
                return;

            _logger?.LogInformation("Drivers fetched from cache: {Count}", drivers.Data?.Count ?? 0);
            foreach (var d in drivers.Data)
            {
                var distance = GeoHelper.CalculateDistance(request.StartLat, request.StartLng, d.Latitude ?? 0, d.Longitude ?? 0);
                if (distance <= _distanceThresholdKm)
                {
                    availableDrivers.Add(d);
                }
            }
            _logger?.LogInformation("Drivers after distance filter: {Count}", availableDrivers.Count);

            var avgRate = client.Rate;

            //var rateCount = client.Rates?.Count ?? 0;
            var tripOffer = new TripOfferDTO
            {
                TripId = trip.Id,
                StartLocation = new LocationDTO
                {
                    Lat = request.StartLat,
                    Lng = request.StartLng,
                    Address = request.StartAddress
                },
                EndLocation = new LocationDTO
                {
                    Lat = request.EndLat,
                    Lng = request.EndLng,
                    Address = request.EndAddress
                },
                Price = trip.Price,
                CreatedAt = trip.CreatedAt,
                PaymentMethod = string.Equals(request.PaymentMethod, "Visa", StringComparison.OrdinalIgnoreCase) ? "Visa" : "Cash",
                Client = new ClientTripDataDTO
                {
                    ClientId = client.Id,
                    FullName = client.Name,
                    PhoneNumber = client.PhoneNumber,
                    ProfileImageUrl = client.ProfilePicture,
                    Rating= (double)client.Rate,
                }
            };
            var sendTasks = new List<Task>();
            foreach (var driver in availableDrivers)
            {
                var groupName = HubGroups.Driver(driver.DriverId);
                try
                {
                    var t = Clients.Group(groupName)
                        .SendAsync(HubEvents.ReceiveNewTrip, tripOffer);

                    sendTasks.Add(t);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex,
                        "Error sending trip offer to driver {DriverId}",
                        driver.DriverId);
                }
                await _notificationService.SendNotificationToUserAsync(driver.DriverId,
                    "طلب رحلة جديد", $"يوجد طلب رحلة جديد بمبلغ {tripOffer.Price}.");
            }
            try
            {
                await Task.WhenAll(sendTasks);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error sending one or more trip offers");
            }

        }

        #endregion

        #region Approved Events

        private async Task NotifyClientTripApproved(string clientId, Trip trip, ApplicationUser driver, string latitude, string longitude)
        {
            await _notificationService.SendNotificationToUserAsync(clientId,
                "تم قبول الرحلة", $"تم قبول رحلتك بواسطة السائق {driver.FullName}.");

            await Clients.Group(HubGroups.User(clientId))
                .SendAsync(HubEvents.TripApprovedForClient, new
                {
                    TripId = trip.Id,
                    DriverId = driver.Id,
                    DriverName = driver.FullName,
                    DriverPhoto = driver.ProfilePicture,
                    DriverPhone = driver.PhoneNumber,
                    Status = trip.Status.ToString(),
                    UpdatedAt = DateTime.Now.ToEgyptTime(),
                    DriverRate = _ratingService.GetAverageRate(driver.Id).Result,
                    DriverRateCount = driver.RatingsReceived.Count,
                    ScooterType = driver.Scooter?.Type.ToString() ?? "",
                    ScooterLicense = driver.Scooter?.License ?? "",
                    DriverLocation = new
                    {
                        Lat = latitude,
                        Lng = longitude
                    }
                });
        }

        private async Task NotifyAdminTripApproved(UserTrip clientInTrip, Trip trip, ApplicationUser driver)
        {
            await Clients.Group(HubGroups.Admin)
                .SendAsync(HubEvents.TripApprovedForAdmin, new
                {
                    TripId = trip.Id,
                    DriverId = driver.Id,
                    DriverName = driver.FullName,
                    DriverPhoto = driver.ProfilePicture,
                    DriverPhone = driver.PhoneNumber,
                    Status = trip.Status.ToString(),
                    ClientId = clientInTrip.UserId,
                    ClientName = clientInTrip.User.FullName,
                    ClientPhone = clientInTrip.User.PhoneNumber,
                    ClientPhoto = clientInTrip.User.ProfilePicture,
                    UpdatedAt = DateTime.Now.ToEgyptTime()
                });
        } 

        private async Task NotifyOtherDriversTripTaken(string tripId, string assignedDriverId, string clientGender)
        {
            var availableDrivers = await _driverService.GetAvailableDriversFromCache(clientGender);
            if (availableDrivers.IsSuccess && availableDrivers.Data != null)
            {
                foreach (var driver in availableDrivers.Data)
                {
                    if (driver.DriverId != assignedDriverId)
                    {
                        await Clients.Group(HubGroups.Driver(driver.DriverId))
                            .SendAsync(HubEvents.TripTakenByAnotherDriver, new
                            {
                                TripId = tripId,
                                Message = "تم قبول الرحلة من قبل سائق آخر",
                                UpdatedAt = DateTime.Now.ToEgyptTime()
                            });
                    }
                }
            }
        }
        #endregion

        #region Arrived Events
        private async Task NotifyClientTripArrived(string clientId, string tripId)
        {
            await _notificationService.SendNotificationToUserAsync(clientId,
                "وصل الكابتن", "وصل الكابتن إلى نقطة الانطلاق، يرجى الاستعداد.");

            await Clients.Group(HubGroups.User(clientId))
                .SendAsync(HubEvents.ClientArrivedTrip, new
                {
                    TripId = tripId,
                    Status = TripStatus.Arrived.ToString(),
                    UpdatedAt = DateTime.Now.ToEgyptTime()
                });
        }

        private async Task NotifyDriverTripArrived(string driverId, string tripId)
        {
            await Clients.Group(HubGroups.Driver(driverId))
                .SendAsync(HubEvents.DriverArrivedTrip, new
                {
                    TripId = tripId,
                    Status = TripStatus.Arrived.ToString(),
                    UpdatedAt = DateTime.Now.ToEgyptTime()
                });
        }
        #endregion

        #region Start Trip Events
        private async Task NotifyClientTripStarted(string clientId, string tripId)
        {
            await _notificationService.SendNotificationToUserAsync(clientId,
                "بدأت رحلتك", "انطلقت رحلتك إلى وجهتك. رحلة سعيدة!");

            await Clients.Group(HubGroups.User(clientId))
                .SendAsync(HubEvents.TripStartedForClient, new
                {
                    TripId = tripId,
                    Status = TripStatus.InProgress.ToString(),
                    UpdatedAt = DateTime.Now.ToEgyptTime()
                });
        }

        private async Task NotifyDriverTripStarted(string driverId, string tripId)
        {
            await Clients.Group(HubGroups.Driver(driverId))
                .SendAsync(HubEvents.TripStartedForDriver, new
                {
                    TripId = tripId,
                    Status = TripStatus.InProgress.ToString(),
                    UpdatedAt = DateTime.Now.ToEgyptTime()
                });
        }
        #endregion

        #region End Trip Events
        private async Task NotifyClientTripEnded(string clientId, string tripId)
        {
            await _notificationService.SendNotificationToUserAsync(clientId,
                "انتهت رحلتك", "وصلت إلى وجهتك بأمان. شكرًا لاختيارك V-Go! 🎉");

            await Clients.Group(HubGroups.User(clientId))
                .SendAsync(HubEvents.TripEndedForClient, new
                {
                    TripId = tripId,
                    Status = TripStatus.Completed.ToString(),
                    UpdatedAt = DateTime.Now.ToEgyptTime()
                });
        }

        private async Task NotifyDriverTripEnded(string driverId, string tripId)
        {
            await Clients.Group(HubGroups.Driver(driverId))
                .SendAsync(HubEvents.TripEndedForDriver, new
                {
                    TripId = tripId,
                    Status = TripStatus.Completed.ToString(),
                    UpdatedAt = DateTime.Now.ToEgyptTime()
                });
        }
        #endregion

        #region Cancelled Trip Events
        private async Task NotifyAdminTripCancelled(string tripId, string userId)
        {
            await Clients.Group(HubGroups.Admin)
                .SendAsync(HubEvents.TripCancelledForAdmin, new
                {
                    TripId = tripId,
                    UserId = userId,
                    Message = "تم إلغاء الرحلة من قبل العميل",
                    Status =TripStatus.Canceled.ToString(),
                    UpdatedAt = DateTime.Now.ToEgyptTime()
                });
        }

        private async Task NotifyClientTripCancelled(string tripId, string userId)
        {
            await Clients.Group(HubGroups.User(userId))
                .SendAsync(HubEvents.TripCancelledForClient, new
                {
                    TripId = tripId,
                    UserId = userId,
                    Message = "تم إلغاء الرحلة من قبلك بنجاح",
                    Status = TripStatus.Canceled.ToString(),
                    UpdatedAt = DateTime.Now.ToEgyptTime()
                });
        }

        private async Task NotifyAvailableDriversTripCancelled(string tripId, string userId, string Gender)
        {
            var availableDrivers = await _driverService.GetAvailableDriversFromCache(Gender);

            if (availableDrivers.IsSuccess && availableDrivers.Data != null)
            {
                var cancellationData = new
                {
                    TripId = tripId,
                    UserId = userId,
                    Message = "تم إلغاء طلب الرحلة من قبل العميل",
                    Status = TripStatus.Canceled.ToString(),
                    UpdatedAt = DateTime.Now.ToEgyptTime()
                };

                foreach (var driver in availableDrivers.Data)
                {
                    await Clients.Group(HubGroups.Driver(driver.DriverId))
                        .SendAsync(HubEvents.TripCancelledByClient, cancellationData);
                }
            }
        }

        private async Task<bool> IsAcceptedTrip(string tripId)
        {
            var trip = await _unitOfWork.Trips.GetByIdAsync(tripId);
            if (trip == null)
                return false;
            return trip.Status == TripStatus.Accepted;
        }

        private async Task NotifyDriverTripCancelled(string tripId, string userId)
        {
            var userTrip = await _context.UserTrips
                .FirstOrDefaultAsync(ut => ut.TripId == tripId && ut.Role == UserTripRole.Driver);

            await _notificationService.SendNotificationToUserAsync(userTrip!.UserId,
                "تم إلغاء الرحلة", "تم إلغاء الرحلة من قِبل العميل.");

            await Clients.Group(HubGroups.Driver(userTrip.UserId))
                .SendAsync(HubEvents.TripCancelledForTripDriver, new
                {
                    TripId = tripId,
                    UserId = userId,
                    Message = "تم إلغاء الرحلة من قِبل العميل",
                    Status = TripStatus.Canceled.ToString(),
                    UpdatedAt = DateTime.Now.ToEgyptTime()
                });
        }
        #endregion

        #region Payment Events
        private async Task NotifyPaymentForDriverAndClient(string userId, string driverId)
        {
            var response = new
            {
                Status = PaymentStatus.Paid.ToString(),
                Message = ".سيتم دفع الرحلة نقدًا"
            };

            await Clients.Group(HubGroups.User(userId))
                .SendAsync(HubEvents.TripPaymentUpdated, response);
            await Clients.Group(HubGroups.Driver(driverId))
                .SendAsync(HubEvents.TripPaymentUpdated, response);
        } 
        #endregion

        #endregion
    }
}
