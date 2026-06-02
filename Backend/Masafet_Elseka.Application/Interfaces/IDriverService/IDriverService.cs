using Masafet_Elseka.Application.Common.Pagination;
using Masafet_Elseka.Application.DTOs.Driver;
using Masafet_Elseka.Application.DTOs.Pagination;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.Interfaces.IDriverService
{
    public interface IDriverService
    {
        public Task<Response<DriverDTO>> GetByIdAsync(string Id);
        public Task<Response<ICollection<DriverStatusDTO>>> GetAvailableDrivers();
        public Task<Response<ICollection<DriverStatusDTO>>> GetAvailableDriversFromCache(string? clientGender = null);
        public Task<Response<bool>> UpdateAvailability(string driverId, bool isAvailable);
        public Task<Response<bool>> UpdateLocation(string driverId, double latitude, double longitude);
        public Task SetDriverStatusToCache(DriverStatusDTO status);
        public Task<bool> CheckScooterData(ApplicationUser driver, DriverUpdateDTO model);
        public Task<Response<PaginationPagedResponse<DriverDTO>>> GetAll(PaginationRequest pagination, string? search, string? gender, ScooterType? scooterType=null, string? profitMethod=null);
    }
}
