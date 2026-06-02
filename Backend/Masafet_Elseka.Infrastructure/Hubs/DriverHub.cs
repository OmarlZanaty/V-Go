using Masafet_Elseka.Application.DTOs.Client;
using Masafet_Elseka.Application.DTOs.Driver;
using Masafet_Elseka.Application.DTOs.Trip;
using Masafet_Elseka.Application.ExternalInterfaces.ICachService;
using Masafet_Elseka.Application.Helpers;
using Masafet_Elseka.Application.Interfaces.IDriverService;
using Masafet_Elseka.Application.Interfaces.IEmergencyService;
using Masafet_Elseka.Application.Interfaces.ITripService;
using Masafet_Elseka.Domain.Const;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.SignalR;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Hubs
{
    //[Authorize(Roles = "Driver", AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    public class DriverHub : Hub
    {
        private readonly IDriverService _driverService;
        private readonly ICacheService _cacheService;
        private static readonly ConcurrentDictionary<string, string> _driversIds = new();
        private readonly ITripService _tripService;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly IHubContext<TripHub> _tripHubContext;
        private readonly IEmergencyService _emergencyService;
        private double _distanceThresholdKm = 4.0;

        public DriverHub(IDriverService driverService, ICacheService cacheService, ITripService tripService, UserManager<ApplicationUser> userManager, IHubContext<TripHub> tripHub, IEmergencyService emergencyService)
        {
            _driverService = driverService;
            _cacheService = cacheService;
            _tripService = tripService;
            _userManager = userManager;
            _tripHubContext = tripHub;
            _emergencyService = emergencyService;
        }

        public override async Task OnConnectedAsync()
        {
            if (Context.User?.Identity?.IsAuthenticated != true)
            {
                Context.Abort();
                return;
            }

            var role = Context.User?.FindFirst(ClaimTypes.Role)?.Value;
            var userId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (role == "Admin" || role == "Dispatcher")
            {
                await Groups.AddToGroupAsync(Context.ConnectionId, "Admin");
            }
            if (role == "Driver")
            {
                await Groups.AddToGroupAsync(Context.ConnectionId, HubGroups.Driver(userId));
                await Groups.AddToGroupAsync(Context.ConnectionId, HubGroups.Drivers);
            }

            await base.OnConnectedAsync();
        }


        //[Authorize(Roles = "Driver")]
        public async Task UpdateDriverStatus(DriverStatusDTO status)
        {
            var driverId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(driverId))
            {
                throw new HubException("Unauthorized driver");
            }

            status.DriverId = driverId;
            if (string.IsNullOrEmpty(status.DriverGender))
            {
                var driver= await _userManager.FindByIdAsync(driverId);
                status.DriverGender = driver?.Gender;
                status.ProfilePhoto = driver?.ProfilePicture;
            }

            _driversIds[Context.ConnectionId] = driverId;
            await _driverService.SetDriverStatusToCache(status);
            await _driverService.UpdateAvailability(driverId, status.IsAvailable);
            if(status.Latitude.HasValue && status.Longitude.HasValue)
            {
                await _driverService.UpdateLocation(driverId, status.Latitude.Value, status.Longitude.Value);
            }

            if (status.IsAvailable)
            {
                await Groups.AddToGroupAsync(Context.ConnectionId, "Drivers");
                await Groups.AddToGroupAsync(Context.ConnectionId, $"Driver_{driverId}");
                await NotifyPendingTripsToDriver(driverId, status.Latitude, status.Longitude);
            }
            else
            {
                await Groups.RemoveFromGroupAsync(Context.ConnectionId, "Drivers");
                await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"Driver_{driverId}");
            }

            await Clients.Group("Admin").SendAsync("ReceiveAvailabilityUpdate", status);
        }

        #region UpdateLocation
        //public async Task UpdateLocation(double latitude, double longitude)
        //{
        //    var driverId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        //    if (string.IsNullOrEmpty(driverId))
        //    {
        //        throw new HubException("Unauthorized driver");
        //    }
        //    await _driverService.UpdateLocation(driverId, latitude, longitude);
        //    var status = _cacheService.GetData<DriverStatusDTO>($"DriverStatus_{driverId}");
        //    if (status != null)
        //    {
        //        status.Latitude = latitude;
        //        status.Longitude = longitude;
        //        await _driverService.SetDriverStatusToCache(status);
        //        await Clients.Group("Admin").SendAsync("ReceiveLocationUpdate", status);
        //    }
        //} 
        #endregion

        //[Authorize(Roles = "Admin,Dispatcher")]
        public async Task GetAvailableDrivers()
        {
            var response = await _driverService.GetAvailableDriversFromCache();
            if (!response.IsSuccess)
            {
                await Clients.Caller.SendAsync("ReceiveAvailableDrivers", new List<DriverStatusDTO>());
                return;
            }

            await Clients.Group("Admin").SendAsync("ReceiveAvailableDrivers", response.Data);
        }

        public async Task SendAlertToAdmin(double latitude, double longitude)
        {
            var driverId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(driverId))
            {
                throw new HubException("Unauthorized driver");
            }

            var response = await _emergencyService.SendAlert(new AlertDTO
            {
                DriverId = driverId,
                Latitude = latitude,
                Longitude = longitude,
            });

            await Clients.Group("Admin").SendAsync("ReceiveDriverAlert", new
            {
                DriverId = driverId,
                DriverName = response.Data.Name ?? "",
                DriverPhone = response.Data.PhoneNumber ?? "",
                DriverProfilePicture = response.Data.ProfilePicture ?? "",
                Latitude = latitude,
                Longitude = longitude,
                Alerttime = DateTime.Now.ToEgyptTime()
            });

        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            if (_driversIds.TryGetValue(Context.ConnectionId, out var driverId))
            {
                await _cacheService.RemoveDataAsync($"DriverStatus_{driverId}");
                //await _driverService.UpdateAvailability(driverId, false);
                await _cacheService.RemoveKeyFromList("DriversStatusKeys", $"DriverStatus_{driverId}");
                _driversIds.Remove(Context.ConnectionId, out _);
            }

            await Groups.RemoveFromGroupAsync(Context.ConnectionId, "Admin");
            await base.OnDisconnectedAsync(exception);
        }
        private async Task NotifyPendingTripsToDriver(string driverId, double? latitude, double? longitude)
        {
            var allTrips = await _tripService.GetAllTripsFromCache();

            if (allTrips == null || !allTrips.Any())
                return;

            var pendingTrips = allTrips.Where(t => t.Status == TripStatus.Pending).ToList();
            if (!pendingTrips.Any())
                return;

            foreach (var trip in pendingTrips)
            {
                if(latitude.HasValue && longitude.HasValue)
                {
                    var distance = trip.DistanceInKm;
                    if (distance > _distanceThresholdKm)
                    {
                        continue;
                    }
                }
                var tripOffer = new TripOfferDTO
                {
                    TripId = trip.Id,
                    StartLocation = new LocationDTO
                    {
                        Lat = trip.StartLat,
                        Lng = trip.StartLng,
                        Address = trip.StartAddress
                    },
                    EndLocation = new LocationDTO
                    {
                        Lat = trip.EndLat,
                        Lng = trip.EndLng,
                        Address = trip.EndAddress
                    },
                    Price = trip.Price,
                    CreatedAt = trip.CreatedAt,
                    Client = new ClientTripDataDTO
                    {
                        ClientId = trip.ClientId,
                        FullName = trip.ClientName,
                        PhoneNumber = trip.ClientPhone,
                        ProfileImageUrl = trip.ClientProfilePicture,
                        Rating = trip.ClientRating,       
                    }
                };
                await _tripHubContext.Clients.Group(HubGroups.Driver(driverId))
                             .SendAsync(HubEvents.RecievePendingTrips, tripOffer);
            }
        }
    }
}
