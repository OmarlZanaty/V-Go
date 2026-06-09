using CloudinaryDotNet.Actions;
using Masafet_Elseka.Application.Common.Pagination;
using Masafet_Elseka.Application.DTOs.Driver;
using Masafet_Elseka.Application.DTOs.Pagination;
using Masafet_Elseka.Application.DTOs.RateDTOs;
using Masafet_Elseka.Application.DTOs.Trip;
using Masafet_Elseka.Application.ExternalInterfaces.ICachService;
using Masafet_Elseka.Application.ExternalInterfaces.ICloudinaryService;
using Masafet_Elseka.Application.Helpers;
using Masafet_Elseka.Application.Interfaces.IDriverService;
using Masafet_Elseka.Application.Interfaces.IRatingService;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Data;
using Masafet_Elseka.Infrastructure.UOW;
using Masafet_Elseka.Infrastructure.Validations;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection.Metadata.Ecma335;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Services.DriverService
{
    public class DriverService : IDriverService
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly ICacheService _cacheService;
        private readonly Context _context;
        private readonly ICloudinaryService _cloudinaryService;
        private readonly IRatingService _ratingService;

        public DriverService(IUnitOfWork unitOfWork, UserManager<ApplicationUser> userManager, ICacheService cacheService,
            Context context, ICloudinaryService cloudinaryService, IRatingService ratingService)
        {
            _unitOfWork = unitOfWork;
            _userManager = userManager;
            _cacheService = cacheService;
            _context = context;
            _cloudinaryService = cloudinaryService;
            _ratingService = ratingService;
        }

        public async Task<Response<DriverDTO>> GetByIdAsync(string Id)
        {
            try
            {
                var driver = await _context.Users.Include(u => u.Scooter).Include(u => u.UserTrips)
                    .FirstOrDefaultAsync(u => u.Id == Id);
                if (driver == null)
                {
                    return Response<DriverDTO>.Failure("السائق غير موجود", 404);
                }

                if (!await _userManager.IsInRoleAsync(driver, "Driver"))
                {
                    return Response<DriverDTO>.Failure("المستخدم ليس سائقًا", 403);
                }

                var rates = await _context.Rates
                    .Where(r => r.ToUserId == Id)
                    .Select(r => new UserRateDTO
                    {
                        Score = r.Score,
                        Comment = r.Comment,
                    }).ToListAsync();

                var driverDto = new DriverDTO
                {
                    Id = driver.Id,
                    Name = driver.FullName,
                    ProfilePicture = driver.ProfilePicture,
                    Gender = driver.Gender,
                    Email=driver.Email,
                    PhoneNumber = driver.PhoneNumber,
                    License = driver.License!,
                    NationalId = driver.NationalId!,
                    ScooterLicense = driver.Scooter?.License,
                    ScooterType = driver.Scooter?.Type ?? ScooterType.Electric,
                    TripCount = driver.UserTrips.Count,     
                    Rate= await _ratingService.GetAverageRate(Id),
                    IsAvailable= driver.IsAvailable ?? false,
                    IsBlocked = driver.IsBlocked,
                    Roles = driver != null ? (await _userManager.GetRolesAsync(driver)).ToList() : new List<string>()
                };
                var Profit = await GetDriverProfit(Id);
                driverDto.Profit= Profit;

                return Response<DriverDTO>.Success(driverDto, "تم جلب بيانات السائق بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<DriverDTO>.Failure($"حدث خطأ أثناء جلب بيانات السائق", 500);
            }
        }

        public async Task<Response<PaginationPagedResponse<DriverDTO>>> GetAll(PaginationRequest pagination, string? search, string? gender, ScooterType? scooterType = null, string? profitMethod = null)
        {
            try
            {
                var query = _context.Users
                    .Include(u => u.Scooter)
                    .Include(u => u.UserTrips)
                    .AsQueryable();

                var drivers = await _userManager.GetUsersInRoleAsync("Driver");
                query = query.Where(u => drivers.Select(d => d.Id).Contains(u.Id));

                if (!string.IsNullOrEmpty(search))
                {
                    query = query.Where(u => u.FullName.Contains(search) ||
                                             u.PhoneNumber!.Contains(search));
                }
                if (!string.IsNullOrEmpty(gender))
                {
                    query = query.Where(u => u.Gender == gender);
                }
                if (scooterType.HasValue)
                {
                    query = query.Where(u => u.Scooter != null && u.Scooter.Type == scooterType);
                }
                var totalCount = await query.CountAsync();

                var pagedDrivers = await query
                    .Skip((pagination.PageNumber - 1) * pagination.PageSize)
                    .Take(pagination.PageSize)
                    .ToListAsync();

                if(!pagedDrivers.Any())
                {
                    return Response<PaginationPagedResponse<DriverDTO>>.Success(new PaginationPagedResponse<DriverDTO>(
                        new List<DriverDTO>(),
                        totalCount,
                        pagination.PageNumber,
                        pagination.PageSize
                        ), "لا يوجد سائقين", 200);
                }

                var driverDtos = new List<DriverDTO>();
                foreach (var driver in pagedDrivers)
                {
                    var rates = await _context.Rates
                        .Where(r => r.ToUserId == driver.Id)
                        .Select(r => new UserRateDTO
                        {
                            Score = r.Score,
                        }).ToListAsync();
                    var driverDto = new DriverDTO
                    {
                        Id = driver.Id,
                        Name = driver.FullName,
                        ProfilePicture = driver.ProfilePicture,
                        PhoneNumber = driver.PhoneNumber,
                        Email = driver.Email,
                        Gender = driver.Gender,
                        License = driver.License!,
                        NationalId = driver.NationalId!,
                        ScooterLicense = driver.Scooter?.License,
                        ScooterType = driver.Scooter?.Type ?? ScooterType.Electric,
                        TripCount = driver.UserTrips.Count,
                        Rate = rates.Any() ? (decimal)Math.Round(rates.Average(r => r.Score), 1) : null,
                        IsAvailable = driver.IsAvailable ?? false,
                        IsBlocked = driver.IsBlocked,
                        Roles = driver != null ? (await _userManager.GetRolesAsync(driver)).ToList() : new List<string>(),
                        Profit = await GetDriverProfit(driver.Id,profitMethod)
                    };
                    driverDtos.Add(driverDto);
                }

                var pagedResponse = new PaginationPagedResponse<DriverDTO>(
                    driverDtos,
                    totalCount,
                    pagination.PageNumber,
                    pagination.PageSize
                    );

                return Response<PaginationPagedResponse<DriverDTO>>.Success(pagedResponse, "تم جلب بيانات السائقين بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<PaginationPagedResponse<DriverDTO>>.Failure($"حدث خطأ أثناء جلب بيانات السائقين", 500);
            }
        }

        public async Task<Response<ICollection<DriverStatusDTO>>> GetAvailableDrivers()
        {
            try
            {
                var drivers = await _userManager.GetUsersInRoleAsync("Driver");
                if (drivers == null || !drivers.Any())
                {
                    return Response<ICollection<DriverStatusDTO>>.Failure("لا يوجد سائقين", 404);
                }

                var availableDrivers = drivers
                    .Where(d => d.IsAvailable.HasValue && d.IsAvailable.Value)
                    .Select(d => new DriverStatusDTO
                    {
                        DriverId = d.Id,
                        DriverName = d.FullName,
                        IsAvailable = d.IsAvailable!.Value,
                        DriverGender=d.Gender,
                        ProfilePhoto = d.ProfilePicture,
                        Latitude = d.Latitude,
                        Longitude = d.Longitude
                    })
                    .ToList();
                if (availableDrivers.Count == 0)
                {
                    return Response<ICollection<DriverStatusDTO>>.Success(new List<DriverStatusDTO>(), "لا يوجد سائقين متاحين", 201);
                }

                return Response<ICollection<DriverStatusDTO>>.Success(availableDrivers, "تم جلب السائقين المتاحين بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<ICollection<DriverStatusDTO>>.Failure($"حدث خطأ أثناء جلب السائقين المتاحين", 500);
            }
        }

        public async Task<Response<ICollection<DriverStatusDTO>>> GetAvailableDriversFromCache(string? clientGender = null)
        {
            try
            {
                var availableDriversKeys = _cacheService.GetData<HashSet<string>>("DriversStatusKeys");

                List<DriverStatusDTO> availableDrivers = new();

                if (availableDriversKeys != null && availableDriversKeys.Any())
                {
                    availableDrivers =  availableDriversKeys
                        .Select(key => _cacheService.GetData<DriverStatusDTO>(key))
                        .Where(d => d != null && d.IsAvailable)
                        .ToList()!;
                }

                if (!availableDrivers.Any())
                {
                    var drivers = await GetAvailableDrivers();
                    if(drivers.Data!=null && drivers.Data.Any())
                    {
                        availableDrivers.AddRange(drivers.Data);
                        foreach (var driver in drivers.Data)
                        {
                            await SetDriverStatusToCache(driver);
                        }
                    }
                }

                if (!string.IsNullOrEmpty(clientGender))
                {
                    availableDrivers = availableDrivers
                        .Where(d => string.Equals(d.DriverGender, clientGender, StringComparison.OrdinalIgnoreCase))
                        .ToList();
                }

                #region can be used for parallel fetching from cache
                //var tasks = availableDriversKeys.Select(key => Task.Run(() =>
                //{
                //    var driverStatus = _cacheService.GetData<DriverStatusDTO>(key);
                //    if (driverStatus != null && driverStatus.IsAvailable)
                //    {
                //        driverStatus.Distance = GeoHelper.CalculateDistance(clientLat, clientLong, driverStatus.Latitude, driverStatus.Longitude);
                //        return driverStatus;
                //    }
                //    return null;
                //}));

                //var results = await Task.WhenAll(tasks);
                //var availableDrivers = results.Where(d => d != null && d.IsAvailable).OrderBy(d => d!.Distance).ToList(); 
                #endregion

                if (!availableDrivers.Any())
                {
                    return Response<ICollection<DriverStatusDTO>>.Success(new List<DriverStatusDTO>(), "لا يوجد سائقين متاحين", 200);
                }

                return Response<ICollection<DriverStatusDTO>>.Success(availableDrivers, "تم جلب السائقين المتاحين بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<ICollection<DriverStatusDTO>>.Failure($"حدث خطأ أثناء جلب السائقين المتاحين", 500);
            }
        }

        public async Task<Response<bool>> UpdateAvailability(string driverId, bool isAvailable)
        {
            try
            {
                // for test bank acc
                // isAvailable = true;

                var driver = await _userManager.FindByIdAsync(driverId);
                if (driver == null)
                {
                    return Response<bool>.Failure("السائق غير موجود", 404);
                }

                if (driver.IsAvailable == isAvailable)
                {
                    return Response<bool>.Success(true, "تم تحديث حالة التوفر بنجاح", 200);
                }

                driver.IsAvailable = isAvailable;
                var result = await _userManager.UpdateAsync(driver);
                if (!result.Succeeded)
                {
                    return Response<bool>.Failure(false, "فشل تحديث حالة التوفر", 400, result.Errors.Select(e => e.Description).ToList());
                }

                #region if needed set to cache
                //await SetDriverStatusToCache(new DriverStatusDTO
                //{
                //    DriverId = driver.Id,
                //    DriverName = driver.FullName,
                //    IsAvailable = isAvailable,
                //    ProfilePhoto = driver.ProfilePicture
                //}); 
                #endregion

                return Response<bool>.Success(true, "تم تحديث حالة التوفر بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<bool>.Failure($"حدث خطأ أثناء تحديث حالة التوفر", 500);
            }
        }

        public async Task<Response<bool>> UpdateLocation(string driverId, double latitude, double longitude)
        {
            try
            {
                var driver = await _userManager.FindByIdAsync(driverId);
                if (driver == null)
                {
                    return Response<bool>.Failure("السائق غير موجود", 404);
                }

                if (driver.Latitude == latitude && driver.Longitude == longitude)
                {
                    return Response<bool>.Success(true, "تم تحديث الموقع بنجاح", 200);
                }
                driver.Latitude = latitude;
                driver.Longitude = longitude;
                var result = await _userManager.UpdateAsync(driver);
                if (!result.Succeeded)
                {
                    return Response<bool>.Failure(false, "فشل تحديث الموقع", 400, result.Errors.Select(e => e.Description).ToList());
                }
                return Response<bool>.Success(true, "تم تحديث الموقع بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<bool>.Failure($"حدث خطأ أثناء تحديث الموقع", 500);
            }
        }

        public async Task SetDriverStatusToCache(DriverStatusDTO status)
        {
            var existingStatus = _cacheService.GetData<DriverStatusDTO>($"DriverStatus_{status.DriverId}");
            if (existingStatus != null)
            {
                existingStatus.DriverId = status.DriverId ?? existingStatus.DriverId;
                existingStatus.IsAvailable = status.IsAvailable;
                existingStatus.Latitude = status.Latitude ?? existingStatus.Latitude;
                existingStatus.Longitude = status.Longitude ?? existingStatus.Longitude;
                existingStatus.DriverName = status.DriverName ?? existingStatus.DriverName;
                existingStatus.ProfilePhoto = status.ProfilePhoto ?? existingStatus.ProfilePhoto;
                existingStatus.DriverGender = status.DriverGender ?? existingStatus.DriverGender;
                status = existingStatus;
            }
            _cacheService.SetData($"DriverStatus_{status.DriverId}", status);
            await _cacheService.SetKeyToList("DriversStatusKeys", $"DriverStatus_{status.DriverId}");
        }

        // Helper
        public async Task<bool> CheckScooterData(ApplicationUser driver, DriverUpdateDTO model)
        {
            try
            {
                var scooter = await _unitOfWork.Scooters.GetByExpressionAsync(s => s.DriverId == driver.Id);
                if (scooter is null)
                {
                    var newScooter = new Scooter
                    {
                        Id = Guid.NewGuid().ToString(),
                        Type = model.ScooterType ?? ScooterType.Electric,
                        License = model.ScooterLicense,
                        DriverId = driver.Id,
                    };

                    var valid = new ScooterValidator().Validate(newScooter);
                    if (!valid.IsValid)
                    {
                        return false;
                    }
                    await _unitOfWork.Scooters.AddAsync(newScooter);
                }
                else
                {
                    scooter.Type = model.ScooterType ?? driver.Scooter!.Type;
                    if (scooter.Type is ScooterType.Electric)
                    {
                        scooter.License = null;
                    }
                    else
                    {
                        scooter.License = model.ScooterLicense ?? driver.Scooter!.License;
                        var valid = new ScooterValidator().Validate(scooter);
                        if (!valid.IsValid)
                        {
                            return false;
                        }
                    }
                }
                await _unitOfWork.Scooters.UpdateAsync(scooter!);
                await _unitOfWork.SaveAsync();
                return true;
            }        
            catch (Exception ex)
            {
                throw new Exception($"حدث خطأ أثناء التحقق من بيانات السكوتر: {ex.Message}");
            }
        }

        private async Task<Dictionary<string,decimal>> GetDriverProfit(string id, string? profitMethod = null)
        {
            try
            {
                Dictionary<string, decimal> profits = new();
                var trips = new List<UserTrip>();

                if(profitMethod == null)
                {
                    trips = await _context.UserTrips.Include(ut => ut.Trip)
                    .Where(ut => ut.UserId == id && ut.Trip.Status == TripStatus.Completed)
                    .ToListAsync();
                }
                else if(profitMethod == "cash")
                {
                    trips = await _context.UserTrips.Include(ut => ut.Trip).ThenInclude(t=>t.Payment)
                    .Where(ut => ut.UserId == id && ut.Trip.Status == TripStatus.Completed
                        && !ut.Trip.Payment.Any())
                    .ToListAsync();
                }
                else
                {
                    trips= await _context.UserTrips.Include(ut => ut.Trip).ThenInclude(t => t.Payment)
                    .Where(ut => ut.UserId == id && ut.Trip.Status == TripStatus.Completed
                        && ut.Trip.Payment.Any(p=>p.TripId==ut.TripId && p.Status==PaymentStatus.Paid))
                    .ToListAsync();
                }

                    var commission = await _unitOfWork.PricingRules.GetFirstOrDefaultAsync();
                var commissionPercentage = commission != null ? commission.DriverCommissionPercentage : 100;

                profits["DailyProfit"] = ((trips.Where(t => t.Date <= DateTime.Now.ToEgyptTime() && t.Date >= DateTime.Now.ToEgyptTime().AddHours(-24))
                    .Select(t => t.Trip.Price).Sum()) * commissionPercentage) / 100;
                profits["WeeklyProfit"] = ((trips.Where(t => t.Date <= DateTime.Now.ToEgyptTime() && t.Date >= DateTime.Now.ToEgyptTime().AddDays(-6))
                    .Select(t => t.Trip.Price).Sum()) * commissionPercentage) / 100;
                profits["MonthlyProfit"] = ((trips.Where(t => t.Date <= DateTime.Now.ToEgyptTime() && t.Date >= DateTime.Now.ToEgyptTime().AddDays(-29))
                    .Select(t => t.Trip.Price).Sum()) *commissionPercentage) / 100;
                profits["AllTimeProfit"] = ((trips.Select(t => t.Trip.Price).Sum()) *commissionPercentage) / 100;

                return profits;
            }
            catch (Exception ex)
            {
                throw new Exception($"حدث خطأ أثناء حساب أرباح السائق: {ex.Message}");
            }
        }
    }
}