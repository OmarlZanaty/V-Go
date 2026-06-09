using Masafet_Elseka.Application.Common.Pagination;
using Masafet_Elseka.Application.DTOs.Trip;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Enums;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.Interfaces.ITripService
{
    public interface ITripService
    {
        public Task<Response<TripResponseDTO>> AddTrip(TripRequest request);
        public Task<Response<PaginationPagedResponse<TripDetailsDTO>>> GetAll(PaginationRequest pagination, TripStatus? status = null, CancellationToken ct = default);
        public Task<Response<TripDetailsDTO>> GetById(string id);
        public Task<Response<PaginationPagedResponse<TripDetailsDTO>>> GetByUserId(string userId, PaginationRequest pagination, CancellationToken ct = default);
        public Task<Response<TripDetailsDTO>> GetCurrentTrip(string userId, UserTripRole role);
        public Task<Response<List<TripDetailsDTO>>> GetCurrentTrips(string userId);
        // Lightweight lookup: the client id of the driver's current active trip
        // (Accepted/Arrived/InProgress), or empty. Used to relay live driver
        // location to the rider during a trip.
        public Task<string> GetActiveTripClientIdAsync(string driverId);
        public Task SetTripToCache(TripResponseDTO trip);
        public Task UpdateTripStateInCache(string tripId, TripStatus newStatus);
        public Task<List<TripResponseDTO>> GetAllTripsFromCache();
        public Task<int> GetTripCountForUser(string userId);
        public Task<Response<List<TripDetailsDTO>>> GetPendingTrips();
        public Task<Response<TripProgressDTO>> ArrivedToTrip(string tripId);
        public Task<Response<TripProgressDTO>> StartTrip(string tripId);
        public Task<Response<TripProgressDTO>> EndTrip(string tripId);
        public Task<Response<string>> CancelTrip(string tripId, string userId);
        public Task<Response<PaginationPagedResponse<DashboardTripDTO>>> GetAllForDashboard(PaginationRequest pagination, TripStatus? status = null, CancellationToken ct = default);
    }
}
