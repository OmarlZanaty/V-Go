
using Masafet_Elseka.Application.Common.Pagination;
using Masafet_Elseka.Application.DTOs.Driver;
using Masafet_Elseka.Application.DTOs.RateDTOs;
using Masafet_Elseka.Application.DTOs.Rating;
using Masafet_Elseka.Application.DTOs.Trip;
using Masafet_Elseka.Application.ExternalInterfaces.ICachService;
using Masafet_Elseka.Application.Helpers;
using Masafet_Elseka.Application.Interfaces.IDriverService;
using Masafet_Elseka.Application.Interfaces.IRatingService;
using Masafet_Elseka.Application.Interfaces.ITripService;
using Masafet_Elseka.Application.Interfaces.User;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Data;
using Masafet_Elseka.Infrastructure.ExtensionMethods;
using Masafet_Elseka.Infrastructure.UOW;
using Microsoft.EntityFrameworkCore;

namespace Masafet_Elseka.Infrastructure.Services.TripService
{
    public class TripService : ITripService
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly Context _context;
        private readonly ICacheService _cacheService;
        private readonly IRatingService _ratingService;
        private readonly IDriverService _driverService;
        private readonly decimal _baseFare = 5; // Meter opening fees
        private readonly decimal _minFare = 10; // minimum trip fees

        public TripService(IUnitOfWork unitOfWork, Context context, ICacheService cacheService, IRatingService ratingService, IDriverService driverService)
        {
            _unitOfWork = unitOfWork;
            _context = context;
            _cacheService = cacheService;
            _ratingService = ratingService;
            _driverService = driverService;
        }

        public async Task<Response<TripResponseDTO>> AddTrip(TripRequest request)
        {
            using var transaction = await _context.Database.BeginTransactionAsync();
            try
            {
                if (request == null)
                {
                    return Response<TripResponseDTO>.Failure("الرحلة غير صالحة", 400);
                }

                var currentKMPrice = await _context.PricingRules.FirstOrDefaultAsync();
                if (currentKMPrice == null)
                {
                    return Response<TripResponseDTO>.Failure("لم يتم تحديد سعر الكيلو", 400);
                }

                //var distance = GeoHelper.CalculateDistance(request.StartLat, request.StartLng, request.EndLat, request.EndLng);
                var totalPrice = (Math.Ceiling((decimal)request.Distance * currentKMPrice.PricePerKm)) + _baseFare;

                var trip = new Trip
                {
                    Price = totalPrice < _minFare ? _minFare : totalPrice,
                    StartLat = request.StartLat,
                    StartLng = request.StartLng,
                    EndLat = request.EndLat,
                    EndLng = request.EndLng,
                    DistanceInKm = request.Distance,
                    StartAddress = request.StartAddress,
                    EndAddress= request.EndAddress,
                    CreatedAt = DateTime.Now.ToEgyptTime(),
                    Status = TripStatus.Pending,
                    PaymentMethod =
                        string.Equals(request.PaymentMethod, "Visa", StringComparison.OrdinalIgnoreCase)
                            ? "Visa"
                            : "Cash",
                };

                var validate = new TripValidator().Validate(trip);
                if (!validate.IsValid)
                {
                    var errorMessages = string.Join(", ", validate.Errors.Select(e => e.ErrorMessage));
                    return Response<TripResponseDTO>.Failure($"Invalid Data Model: {errorMessages}", 400);
                }

                await _context.Trips.AddAsync(trip);
                await _context.SaveChangesAsync();

                await transaction.CommitAsync();

                var result = new TripResponseDTO
                {
                    Id = trip.Id,
                    Price = trip.Price,
                    StartLat = trip.StartLat,
                    StartLng = trip.StartLng,
                    EndLat = trip.EndLat,
                    EndLng = trip.EndLng,
                    DistanceInKm = trip.DistanceInKm,
                    StartAddress = trip.StartAddress,
                    EndAddress= trip.EndAddress,
                    CreatedAt = trip.CreatedAt,
                    Status = trip.Status,
                    PaymentMethod = trip.PaymentMethod
                };

                return Response<TripResponseDTO>.Success(result, "تم إضافة الرحلة بنجاح", 201);
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync();
                return Response<TripResponseDTO>.Failure(new TripResponseDTO(), "حدث خطأ غير متوقع، يرجى المحاولة لاحقًا", 500);
            }
        }

        public async Task<Response<string>> CancelTrip(string tripId, string userId, string? reason = null)
        {
            using var transaction = await _context.Database.BeginTransactionAsync();
            try
            {
                var trip = await _context.Trips
                    .Include(t => t.UserTrips).ThenInclude(ut=>ut.User)
                    .FirstOrDefaultAsync(t => t.Id == tripId);
                if (trip == null)
                {
                    return Response<string>.Failure("الرحلة غير موجودة", 404);
                }
                var userTrip = trip.UserTrips.FirstOrDefault(ut => ut.UserId == userId && ut.Role == UserTripRole.Client && ut.TripId==tripId);
                if (userTrip == null)
                {
                    return Response<string>.Failure("المستخدم غير مرتبط بهذه الرحلة", 403);
                }
                if (trip.Status == TripStatus.InProgress || trip.Status == TripStatus.Completed)
                {
                    return Response<string>.Failure("لا يمكن إلغاء الرحلة لأنها في حالة جارية أو مكتملة", 400);
                }
                trip.Status = TripStatus.Canceled;
                trip.CancelReason = string.IsNullOrWhiteSpace(reason) ? null : reason.Trim();
                await _context.SaveChangesAsync();
                await transaction.CommitAsync();
                return Response<string>.Success(userTrip.User.Gender, "تم إلغاء الرحلة بنجاح", 200);

            }
            catch(Exception ex)
            {
                await transaction.RollbackAsync();
                return Response<string>.Failure("حدث خطأ أثناء إلغاء الرحلة", "حدث خطأ غير متوقع، يرجى المحاولة لاحقًا", 500);
            }

        }
        public async Task<Response<PaginationPagedResponse<TripDetailsDTO>>> GetAll( PaginationRequest pagination,TripStatus? status = null, CancellationToken ct = default)
        {
            try
            {
                var tripsQuery = _context.Trips
                    .Include(t => t.UserTrips)
                        .ThenInclude(ut => ut.User)
                    .AsQueryable();

                if (status.HasValue)
                    tripsQuery = tripsQuery.Where(t => t.Status == status.Value);

                tripsQuery = tripsQuery.OrderByDescending(t => t.CreatedAt);

                var totalCount = await tripsQuery.CountAsync(ct);

                var trips = await tripsQuery
                    .Skip((pagination.PageNumber - 1) * pagination.PageSize)
                    .Take(pagination.PageSize)
                    .ToListAsync(ct);
                var rates = await _ratingService.GetAverageRatesFor(
                    trips.SelectMany(t => t.UserTrips).Select(ut => ut.UserId));
                var tripDtos = trips.Select(trip =>
                {
                    var passengerTrip = trip.UserTrips.FirstOrDefault(ut => ut.Role == UserTripRole.Client);
                    var driverTrip = trip.UserTrips.FirstOrDefault(ut => ut.Role == UserTripRole.Driver);

                    return new TripDetailsDTO
                    {
                        TripId = trip.Id,
                        Price = trip.Price,
                        From = new LocationDTO { Lat = trip.StartLat, Lng = trip.StartLng, Address = trip.StartAddress },
                        To = new LocationDTO { Lat = trip.EndLat, Lng = trip.EndLng, Address = trip.EndAddress },
                        CreatedAt = trip.CreatedAt,
                        UserId = passengerTrip?.User.Id,
                        UserName = passengerTrip?.User.FullName,
                        UserPhone = passengerTrip?.User.PhoneNumber,
                        UserProfileImage = passengerTrip?.User.ProfilePicture,
                        Userrating = passengerTrip != null ? rates.GetValueOrDefault(passengerTrip.UserId) : 0,
                        DriverId = driverTrip != null ? driverTrip.User.Id : null,
                        DriverName = driverTrip != null ? driverTrip.User.FullName : "لم يتم تحديد سائق حتى الان",
                        DriverPhone = driverTrip != null ? driverTrip.User.PhoneNumber : "لم يتم تحديد سائق حتى الان",
                        DriverProfileImage = driverTrip?.User.ProfilePicture,
                        DriverRating = driverTrip != null ? rates.GetValueOrDefault(driverTrip.UserId) : 0,
                        Status = trip.Status.ToString(),
                        DistanceKm = trip.DistanceInKm,
                    };
                }).ToList();

                var pagedResponse = new PaginationPagedResponse<TripDetailsDTO>(
                    tripDtos,
                    totalCount,
                    pagination.PageNumber,
                    pagination.PageSize
                );
                if (!tripDtos.Any())
                {
                    pagedResponse.Data= new List<TripDetailsDTO>();
                    return Response<PaginationPagedResponse<TripDetailsDTO>>.Success(pagedResponse, "لا توجد رحلات متاحة", 200);
                }

                return Response<PaginationPagedResponse<TripDetailsDTO>>.Success(pagedResponse, "تم استرجاع الرحلات بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<PaginationPagedResponse<TripDetailsDTO>>.Failure(null, $"حدث خطأ", 500);
            }
        }
        public async Task<Response<TripDetailsDTO>> GetCurrentTrip(string userId, UserTripRole role)
        {
            try
            {
                IQueryable<Trip> query = _context.Trips
                    .Include(t => t.UserTrips)
                        .ThenInclude(ut => ut.User).ThenInclude(u => u.Scooter)
                        .Include(t => t.UserRates)
                        .Include(t => t.Payment);

                if (role == UserTripRole.Client)
                {
                    query = query.Where(t =>
                        (t.Status == TripStatus.Pending ||
                         t.Status == TripStatus.Accepted ||
                         t.Status == TripStatus.InProgress ||
                         t.Status == TripStatus.Arrived) &&
                        t.UserTrips.Any(ut => ut.UserId == userId && ut.Role == UserTripRole.Client));
                }
                else if (role == UserTripRole.Driver)
                {
                    query = query.Where(t =>
                        (t.Status == TripStatus.Accepted ||
                         t.Status == TripStatus.InProgress ||
                         t.Status == TripStatus.Arrived) &&
                        t.UserTrips.Any(ut => ut.UserId == userId && ut.Role == UserTripRole.Driver));
                }

                var trip = await query.FirstOrDefaultAsync();

                if (trip == null)
                {
                    return Response<TripDetailsDTO>.Failure(null, "لا توجد رحلة حالية", 404);
                }

                var passengerTrip = trip.UserTrips.FirstOrDefault(ut => ut.Role == UserTripRole.Client);
                var driverTrip = trip.UserTrips.FirstOrDefault(ut => ut.Role == UserTripRole.Driver);

                var tripDto = new TripDetailsDTO
                {
                    TripId = trip.Id,
                    Price = trip.Price,
                    From = new LocationDTO { Lat = trip.StartLat, Lng = trip.StartLng, Address = trip.StartAddress },
                    To = new LocationDTO { Lat = trip.EndLat, Lng = trip.EndLng, Address = trip.EndAddress },
                    CreatedAt = trip.CreatedAt,
                    IsPaid = trip.Payment.Any(p => p.Status == PaymentStatus.Paid || p.Status == PaymentStatus.Captured),
                    PaymentMethod = trip.PaymentMethod,

                    UserId = passengerTrip?.User?.Id,
                    UserName = passengerTrip?.User?.FullName,
                    UserProfileImage = passengerTrip?.User?.ProfilePicture,
                    UserPhone = passengerTrip?.User?.PhoneNumber,
                    Userrating = passengerTrip != null ? await _ratingService.GetAverageRate(passengerTrip.UserId) : 0,

                    DriverId = driverTrip?.User?.Id ?? string.Empty,
                    DriverName = driverTrip?.User?.FullName ?? "لم يتم تحديد سائق حتى الان",
                    DriverPhone = driverTrip?.User?.PhoneNumber ?? "لم يتم تحديد سائق حتى الان",
                    DriverProfileImage = driverTrip?.User?.ProfilePicture,
                    DriverRating = driverTrip != null ? await _ratingService.GetAverageRate(driverTrip.UserId): 0,
                    ScooterType = driverTrip?.User?.Scooter?.Type.ToString(),
                    ScooterLicense = driverTrip?.User?.Scooter?.License ?? "",

                    Status = trip.Status.ToString(),
                    DistanceKm = trip.DistanceInKm,
                };


                return Response<TripDetailsDTO>.Success(tripDto, "تم استرجاع الرحلة الحالية بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<TripDetailsDTO>.Failure(null, "حدث خطأ غير متوقع، يرجى المحاولة لاحقًا", 500);
            }
        }

        public async Task<Response<List<TripDetailsDTO>>> GetCurrentTrips(string userId)
        {
            try
            {
                IQueryable<Trip> query = _context.Trips
                    .Include(t => t.UserTrips)
                        .ThenInclude(ut => ut.User).ThenInclude(u => u.Scooter)
                        .Include(t => t.UserRates)
                        .Where(t=>
                            (t.Status == TripStatus.Pending ||
                             t.Status == TripStatus.Accepted ||
                             t.Status == TripStatus.InProgress ||
                             t.Status == TripStatus.Arrived) &&
                            t.UserTrips.Any(ut => ut.UserId == userId && ut.Role==UserTripRole.Client));
                if (query == null)
                {
                    return Response<List<TripDetailsDTO>>.Failure(new List<TripDetailsDTO>(), "لا توجد رحلات حالية", 404);
                }

                var trips = await query.ToListAsync();
                if(trips.Count == 0)
                {
                    return Response<List<TripDetailsDTO>>.Success(new List<TripDetailsDTO>(), "لا توجد رحلات حالية", 200);
                }

                var rates = await _ratingService.GetAverageRatesFor(
                    trips.SelectMany(t => t.UserTrips).Select(ut => ut.UserId));
                var tripDtos = trips.Select(trip =>
                {
                    var passengerTrip = trip.UserTrips.FirstOrDefault(ut => ut.Role == UserTripRole.Client);
                    var driverTrip = trip.UserTrips.FirstOrDefault(ut => ut.Role == UserTripRole.Driver);
                    return new TripDetailsDTO
                    {
                        TripId = trip.Id,
                        Price = trip.Price,
                        From = new LocationDTO { Lat = trip.StartLat, Lng = trip.StartLng, Address = trip.StartAddress },
                        To = new LocationDTO { Lat = trip.EndLat, Lng = trip.EndLng, Address = trip.EndAddress },
                        CreatedAt = trip.CreatedAt,
                        UserId = passengerTrip?.User?.Id,
                        UserName = passengerTrip?.User?.FullName,
                        UserProfileImage = passengerTrip?.User?.ProfilePicture,
                        UserPhone = passengerTrip?.User?.PhoneNumber,
                        Userrating = passengerTrip != null ? rates.GetValueOrDefault(passengerTrip.UserId) : 0,
                        DriverId = driverTrip?.User?.Id ?? string.Empty,
                        DriverName = driverTrip?.User?.FullName ?? "لم يتم تحديد سائق حتى الان",
                        DriverPhone = driverTrip?.User?.PhoneNumber ?? "لم يتم تحديد سائق حتى الان",
                        DriverProfileImage = driverTrip?.User?.ProfilePicture,
                        DriverRating = driverTrip != null ? rates.GetValueOrDefault(driverTrip.UserId) : 0,
                        ScooterType = driverTrip?.User?.Scooter?.Type.ToString(),
                        ScooterLicense = driverTrip?.User?.Scooter?.License ?? "",
                        Status = trip.Status.ToString(),
                        DistanceKm = trip.DistanceInKm,
                    };
                }).ToList();
                return Response<List<TripDetailsDTO>>.Success(tripDtos, "تم استرجاع الرحلات الحالية بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<List<TripDetailsDTO>>.Failure(new List<TripDetailsDTO>(), "حدث خطأ غير متوقع، يرجى المحاولة لاحقًا", 500);
            }
        }

        public async Task<Response<TripProgressDTO>> StartTrip(string tripId)
        {
            using var transaction = await _context.Database.BeginTransactionAsync();
            try
            {
                var trip = await _unitOfWork.Trips
                    .GetByExpressionAsync(t => t.Id == tripId && t.Status == TripStatus.Arrived);

                var clientId = await _context.UserTrips
                    .Where(ut => ut.TripId == tripId && ut.Role == UserTripRole.Client)
                    .Select(ut => ut.UserId)
                    .FirstOrDefaultAsync();
                var driverId = await _context.UserTrips
                  .Where(ut => ut.TripId == tripId && ut.Role == UserTripRole.Driver)
                  .Select(ut => ut.UserId)
                  .FirstOrDefaultAsync();


                if (trip == null)
                {
                    return Response<TripProgressDTO>.Failure("الرحلة غير موجودة أو ليست في حالة معلقة", 404);
                }
                if (trip.Status == TripStatus.InProgress)
                {
                    return Response<TripProgressDTO>.Failure("الرحلة قد بدأت بالفعل", 400);
                }
                trip.Status = TripStatus.InProgress;
                trip.StartTime = DateTime.Now.ToEgyptTime();
                await _context.SaveChangesAsync();
                await transaction.CommitAsync();
                return Response<TripProgressDTO>.Success(new TripProgressDTO { CLientId= clientId! , DriverId=driverId!, PaymentMethod = trip.PaymentMethod }, "تم بدء الرحلة بنجاح", 200);
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync();
                return Response<TripProgressDTO>.Failure( $"حدث خطأ أثناء بدء هذه الرحلة", 500);
            }
        }

        public async Task<Response<TripProgressDTO>> ArrivedToTrip(string tripId)
        {
            using var transaction = await _context.Database.BeginTransactionAsync();
            try
            {
                var trip = await _unitOfWork.Trips
                         .GetByExpressionAsync(t => t.Id == tripId && t.Status == TripStatus.Accepted);
                if (trip == null) {
                    return Response<TripProgressDTO>.Failure("الرحلة غير موجودة أو ليست في حالة جارية", 404);
                }
                var usertrip = await _unitOfWork.UserTrips.GetByExpressionAsync(ut => ut.TripId == tripId);

                var Client = await _unitOfWork.UserTrips.GetByExpressionAsync(ut => ut.TripId == tripId && ut.Role == UserTripRole.Client);
                var Driver = await _unitOfWork.UserTrips.GetByExpressionAsync(ut => ut.TripId == tripId && ut.Role == UserTripRole.Driver);
                if (usertrip == null) {
                    return Response<TripProgressDTO>.Failure("لم يتم العثور على سجل موجود لهذه الرحلة حتى الان", 404);
                }
                if (Client == null)
                {
                    return Response<TripProgressDTO>.Failure("لم يتم اسناد هذه الرحلة لهذا المستخدم", 404);
                }
                if (Driver == null)
                {
                    return Response<TripProgressDTO>.Failure("لم يتم اسناد هذه الرحلة لهذا السواق", 404);
                }
               
                trip.Status = TripStatus.Arrived;
                await _unitOfWork.SaveAsync();
                await transaction.CommitAsync();
               
                return Response<TripProgressDTO>.Success(new TripProgressDTO { CLientId = Client.UserId!, DriverId = Driver.UserId! }, "تم الوصول الى الرحلة بنجاح", 200);

            }
            catch (Exception ex)
            { 
                await transaction.RollbackAsync();
                return Response<TripProgressDTO>.Failure($"حدث خطأ أثناء بدء هذه الرحلة", 500);
            }
        }
        public async Task<Response<TripProgressDTO>> EndTrip(string tripId)
        {
            using var transaction = await _context.Database.BeginTransactionAsync();
            try
            {
                var trip = await _context.Trips.Include(t => t.Payment)
                    .FirstOrDefaultAsync(t => t.Id == tripId && (t.Status == TripStatus.InProgress || t.Status == TripStatus.Pending));

                var clientId = await _context.UserTrips
                 .Where(ut => ut.TripId == tripId && ut.Role == UserTripRole.Client)
                 .Select(ut => ut.UserId)
                 .FirstOrDefaultAsync();
                var driver = await _context.UserTrips
                    .Include(u=>u.User)
                  .Where(ut => ut.TripId == tripId && ut.Role == UserTripRole.Driver)
                  //.Select(ut => ut.UserId)
                  .FirstOrDefaultAsync();

                if (trip == null)
                {
                    return Response<TripProgressDTO>.Failure("الرحلة غير موجودة أو ليست في حالة جارية", 404);
                }
                //if (!trip.Payment.Any(p => p.Status == PaymentStatus.Paid)) // handle if client not paid yet and try to end the trip
                //{
                //    return Response<TripProgressDTO>.Failure("يرجى دفع ثمن الرحلة حتى يتم الانهاء", 400);
                //}
                if (trip.Status == TripStatus.Completed)
                {
                    return Response<TripProgressDTO>.Failure("الرحلة قد انتهت بالفعل", 400);
                }
                trip.Status = TripStatus.Completed;
                trip.EndTime = DateTime.Now.ToEgyptTime();
                driver!.User.IsAvailable = true;
                await _driverService.UpdateLocation(driver.UserId, trip.EndLat, trip.EndLng);
                await _driverService.SetDriverStatusToCache(new DriverStatusDTO
                {
                    DriverId = driver.UserId!,
                    IsAvailable = true,
                    Latitude = trip.EndLat,
                    Longitude = trip.EndLng,
                    DriverName = driver.User.FullName,
                    ProfilePhoto = driver.User.ProfilePicture ?? "",
                });
                await _context.SaveChangesAsync();
                await transaction.CommitAsync();
                return Response<TripProgressDTO>.Success(new TripProgressDTO { CLientId = clientId!, DriverId = driver.Id! }, "تم إنهاء الرحلة بنجاح", 200);
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync();
                return Response<TripProgressDTO>.Failure( $"حدث خطأ أثناء إنهاء هذه الرحلة", 500);
            }
        }
        public async Task<Response<List<TripDetailsDTO>>> GetPendingTrips()
        {
            try
            {
                var trips = await _context.Trips
                    .Include(ut => ut.UserTrips)
                        .ThenInclude(us => us.User)
                        .Where(t => t.Status ==TripStatus.Pending)
                    .ToListAsync();

                var rates = await _ratingService.GetAverageRatesFor(
                    trips.SelectMany(t => t.UserTrips).Select(ut => ut.UserId));
                var tripDtos = trips.Select(trip =>
                {
                    var passengerTrip = trip.UserTrips.FirstOrDefault(ut => ut.Role == UserTripRole.Client);
                    var driverTrip = trip.UserTrips.FirstOrDefault(ut => ut.Role == UserTripRole.Driver);

                    return new TripDetailsDTO
                    {
                        TripId = trip.Id,
                        Price = trip.Price,
                        From = new LocationDTO { Lat = trip.StartLat, Lng = trip.StartLng, Address = trip.StartAddress },
                        To = new LocationDTO { Lat = trip.EndLat, Lng = trip.EndLng, Address = trip.EndAddress },
                        CreatedAt = trip.CreatedAt,
                        UserId = passengerTrip?.User.Id,
                        UserName = passengerTrip?.User.FullName,
                        UserPhone = passengerTrip?.User.PhoneNumber,
                        DriverId = driverTrip != null ? driverTrip.User.Id : "لم يتم تحديد سائق حتى الان",
                        DriverName = driverTrip != null ? driverTrip.User.FullName : "لم يتم تحديد سائق حتى الان",
                        DriverPhone = driverTrip != null ? driverTrip.User.PhoneNumber : "لم يتم تحديد سائق حتى الان",
                        Status = trip.Status.ToString(),
                        DistanceKm = trip.DistanceInKm,
                        PaymentMethod = trip.PaymentMethod,
                        DriverRating= driverTrip != null ? rates.GetValueOrDefault(driverTrip.UserId) : 0,
                        Userrating= passengerTrip != null ? rates.GetValueOrDefault(passengerTrip.UserId) : 0,
                    };
                }).ToList();
                if (!tripDtos.Any())
                {
                    return Response<List<TripDetailsDTO>>.Success(new List<TripDetailsDTO>(), "لا توجد رحلات متاحة", 200);
                }

                return Response<List<TripDetailsDTO>>.Success(tripDtos, "تم استرجاع الرحلات بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<List<TripDetailsDTO>>.Failure(new List<TripDetailsDTO>(), "حدث خطأ غير متوقع، يرجى المحاولة لاحقًا", 500);
            }
        }

        public async Task<Response<TripDetailsDTO>> GetById(string tripId)
        {
            try
            {
                var trip = await _context.Trips
                    .Include(ut => ut.UserTrips)
                        .ThenInclude(us => us.User)
                    .FirstOrDefaultAsync(t => t.Id == tripId);
                if (trip == null)
                {
                    return Response<TripDetailsDTO>.Failure(new TripDetailsDTO(), "الرحلة غير موجودة", 404);
                }
                var passengerTrip = trip.UserTrips.FirstOrDefault(ut => ut.Role == UserTripRole.Client);
                var driverTrip = trip.UserTrips.FirstOrDefault(ut => ut.Role == UserTripRole.Driver);
                var tripDto = new TripDetailsDTO
                {
                    TripId = trip.Id,
                    Price = trip.Price,
                    From = new LocationDTO { Lat = trip.StartLat, Lng = trip.StartLng, Address = trip.StartAddress },
                    To = new LocationDTO { Lat = trip.EndLat, Lng = trip.EndLng, Address = trip.EndAddress },
                    CreatedAt = trip.CreatedAt,
                    UserId = passengerTrip?.User.Id,
                    UserName = passengerTrip?.User.FullName,
                    UserPhone = passengerTrip?.User.PhoneNumber,
                    DriverId = driverTrip != null ? driverTrip.User.Id : "لم يتم تحديد سائق حتى الان",
                    DriverName = driverTrip != null ? driverTrip.User.FullName : "لم يتم تحديد سائق حتى الان",
                    DriverPhone = driverTrip != null ? driverTrip.User.PhoneNumber : "لم يتم تحديد سائق حتى الان",
                    Status = trip.Status.ToString(),
                    DistanceKm = trip.DistanceInKm,
                    Ratings = await _ratingService.GetCurrentUserTripRates()
                };
                return Response<TripDetailsDTO>.Success(tripDto, "تم استرجاع الرحلة بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<TripDetailsDTO>.Failure(new TripDetailsDTO(), "حدث خطأ غير متوقع، يرجى المحاولة لاحقًا", 500);
            }
        }

        // Lightweight projection used to relay live driver location: returns the
        // client id of the driver's active trip (Accepted/Arrived/InProgress).
        public async Task<string> GetActiveTripClientIdAsync(string driverId)
        {
            try
            {
                var clientId = await _context.Trips
                    .Where(t =>
                        (t.Status == TripStatus.Accepted ||
                         t.Status == TripStatus.Arrived ||
                         t.Status == TripStatus.InProgress) &&
                        t.UserTrips.Any(ut => ut.UserId == driverId && ut.Role == UserTripRole.Driver))
                    .OrderByDescending(t => t.CreatedAt)
                    .Select(t => t.UserTrips
                        .Where(ut => ut.Role == UserTripRole.Client)
                        .Select(ut => ut.UserId)
                        .FirstOrDefault())
                    .FirstOrDefaultAsync();
                return clientId ?? string.Empty;
            }
            catch
            {
                return string.Empty;
            }
        }

        public async Task<Response<PaginationPagedResponse<TripDetailsDTO>>> GetByUserId( string userId,PaginationRequest pagination,CancellationToken ct = default)
        {
            try
            {
                var userTripsQuery = _context.UserTrips
                    .Include(ut => ut.Trip)
                        .ThenInclude(t => t.UserTrips)
                            .ThenInclude(ut => ut.User)
                    .Include(ut => ut.Trip)
                        .ThenInclude(t => t.Payment)
                    .Where(ut => ut.UserId == userId)
                    .AsQueryable();

                // ترتيب حسب تاريخ إنشاء الرحلة تنازلياً (زي GetAll)
                userTripsQuery = userTripsQuery
                    .OrderByDescending(ut => ut.Trip.CreatedAt);

                var totalCount = await userTripsQuery.CountAsync(ct);

                var userTrips = await userTripsQuery
                    .Skip((pagination.PageNumber - 1) * pagination.PageSize)
                    .Take(pagination.PageSize)
                    .ToListAsync(ct);

                var rates = await _ratingService.GetAverageRatesFor(
                    userTrips.SelectMany(ut => ut.Trip.UserTrips).Select(x => x.UserId));
                var tripDtos = userTrips.Select(ut =>
                {
                    var trip = ut.Trip;

                    var passengerTrip = trip.UserTrips.FirstOrDefault(tut => tut.Role == UserTripRole.Client);
                    var driverTrip = trip.UserTrips.FirstOrDefault(tut => tut.Role == UserTripRole.Driver);

                    return new TripDetailsDTO
                    {
                        TripId = trip.Id,
                        Price = trip.Price,
                        From = new LocationDTO { Lat = trip.StartLat, Lng = trip.StartLng, Address = trip.StartAddress },
                        To = new LocationDTO { Lat = trip.EndLat, Lng = trip.EndLng, Address = trip.EndAddress },
                        CreatedAt = trip.CreatedAt,
                        UserId = passengerTrip?.User.Id,
                        UserName = passengerTrip?.User.FullName,
                        UserPhone = passengerTrip?.User.PhoneNumber,
                        Userrating = passengerTrip != null ? rates.GetValueOrDefault(passengerTrip.UserId) : 0,
                        DriverId = driverTrip != null ? driverTrip.User.Id : "لم يتم تحديد سائق حتى الان",
                        DriverName = driverTrip != null ? driverTrip.User.FullName : "لم يتم تحديد سائق حتى الان",
                        DriverPhone = driverTrip != null ? driverTrip.User.PhoneNumber : "لم يتم تحديد سائق حتى الان",
                        DriverRating = driverTrip != null ? rates.GetValueOrDefault(driverTrip.UserId) : 0,
                        Status = trip.Status.ToString(),
                        DistanceKm = trip.DistanceInKm,
                        // Was never set → every trip showed "awaiting payment" in
                        // the captain's earnings regardless of actual status.
                        IsPaid = trip.Payment.Any(p => p.Status == PaymentStatus.Paid || p.Status == PaymentStatus.Captured),
                    };
                }).ToList();

                var pagedResponse = new PaginationPagedResponse<TripDetailsDTO>(
                    tripDtos,
                    totalCount,
                    pagination.PageNumber,
                    pagination.PageSize
                );

                if (!tripDtos.Any())
                {
                    pagedResponse.Data = new List<TripDetailsDTO>();
                    return Response<PaginationPagedResponse<TripDetailsDTO>>.Success(pagedResponse, "لا توجد رحلات لهذا المستخدم", 200);
                }

                return Response<PaginationPagedResponse<TripDetailsDTO>>.Success(pagedResponse, "تم جلب الرحلات بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<PaginationPagedResponse<TripDetailsDTO>>.Failure(null, $"حدث خطأ", 500);
            }
        }

        public async Task<int> GetTripCountForUser(string userId)
        {
            if (userId == null) { return 0; }
            var tripsCount = await _context.UserTrips
                .Include(ut=>ut.Trip)
                .Where(us => us.UserId == userId && us.Trip.Status==TripStatus.Completed)
                .ToListAsync();
            
                return tripsCount.Count;     
        }

        public async Task SetTripToCache(TripResponseDTO trip)
        {
            if (trip == null || string.IsNullOrWhiteSpace(trip.Id))
                return;

            var cacheKey = $"Trip_{trip.Id}";

            _cacheService.SetData(cacheKey, trip);
            await _cacheService.SetKeyToList("TripsKeys", cacheKey);
        }

        public async Task UpdateTripStateInCache(string tripId, TripStatus newStatus)
        {
            if (string.IsNullOrWhiteSpace(tripId))
                return;

            var cacheKey = $"Trip_{tripId}";

          
            var trip = _cacheService.GetData<TripResponseDTO>(cacheKey);

            if (trip == null)
                return;

            trip.Status = newStatus;

            _cacheService.SetData(cacheKey, trip);

            await _cacheService.SetKeyToList("TripsKeys", cacheKey);
        }

        public async Task<List<TripResponseDTO>> GetAllTripsFromCache()
        {
            var keys = _cacheService.GetData<HashSet<string>>("TripsKeys");

            var trips = new List<TripResponseDTO>();

            if (keys == null || keys.Count == 0)
                return trips;

            foreach (var key in keys)
            {
                var trip = _cacheService.GetData<TripResponseDTO>(key);
                if (trip != null)
                    trips.Add(trip);
            }

            return trips;
        }

        public async Task<Response<PaginationPagedResponse<DashboardTripDTO>>> GetAllForDashboard(PaginationRequest pagination, TripStatus? status = null, CancellationToken ct = default)
        {
            try
            {
                var tripsQuery = _context.Trips
                    .Include(t => t.UserTrips)
                        .ThenInclude(ut => ut.User)
                    .AsQueryable();

                if (status.HasValue)
                    tripsQuery = tripsQuery.Where(t => t.Status == status.Value);

                tripsQuery = tripsQuery.OrderByDescending(t => t.CreatedAt);

                var totalCount = await tripsQuery.CountAsync(ct);

                var trips = await tripsQuery
                    .Skip((pagination.PageNumber - 1) * pagination.PageSize)
                    .Take(pagination.PageSize)
                    .ToListAsync(ct);

                // Batch-load average ratings for every user on this page in ONE query.
                // Previously each row called GetAverageRate(...).Result twice (client + driver),
                // producing ~2*PageSize blocking queries (the dashboard N+1).
                var userIds = trips
                    .SelectMany(t => t.UserTrips)
                    .Select(ut => ut.UserId)
                    .Distinct()
                    .ToList();

                var avgRates = await _context.Rates.AsNoTracking()
                    .Where(r => userIds.Contains(r.ToUserId))
                    .GroupBy(r => r.ToUserId)
                    .Select(g => new { UserId = g.Key, Avg = g.Average(x => (double)x.Score) })
                    .ToDictionaryAsync(x => x.UserId, x => x.Avg, ct);

                decimal RateFor(string? uid) =>
                    uid != null && avgRates.TryGetValue(uid, out var avg)
                        ? (decimal)Math.Round(avg, 1)
                        : 0;

                var tripDtos = trips.Select(trip =>
                {
                    var passengerTrip = trip.UserTrips.FirstOrDefault(ut => ut.Role == UserTripRole.Client);
                    var driverTrip = trip.UserTrips.FirstOrDefault(ut => ut.Role == UserTripRole.Driver);

                    return new DashboardTripDTO
                    {
                        TripId = trip.Id,
                        Price = trip.Price,
                        From = trip.StartAddress!,
                        To = trip.EndAddress!,
                        CreatedAt = trip.CreatedAt,
                        ClientName = passengerTrip?.User.FullName!,
                        ClientRate = RateFor(passengerTrip?.UserId),
                        DriverName = driverTrip != null ? driverTrip.User.FullName : "لم يتم تحديد سائق حتى الان",
                        DriverRate = RateFor(driverTrip?.UserId),
                        Status = trip.Status.ToString(),
                        DistanceKm = trip.DistanceInKm,
                    };
                }).ToList();

                var pagedResponse = new PaginationPagedResponse<DashboardTripDTO>(
                    tripDtos,
                    totalCount,
                    pagination.PageNumber,
                    pagination.PageSize
                );
                pagedResponse.Statistics = new Dictionary<string, int>
                {
                    {"TotalTrips", await _context.Trips.CountAsync() },
                    { "PendingTrips", await _context.Trips.CountAsync(t => t.Status == TripStatus.Pending) },
                    { "InProgressTrips", await _context.Trips.CountAsync(t => t.Status == TripStatus.InProgress) },
                    { "CompletedTrips", await _context.Trips.CountAsync(t => t.Status == TripStatus.Completed) },
                    { "CanceledTrips", await _context.Trips.CountAsync(t => t.Status == TripStatus.Canceled)   }
                };

                if (!tripDtos.Any())
                {
                    pagedResponse.Data = new List<DashboardTripDTO>();
                    return Response<PaginationPagedResponse<DashboardTripDTO>>.Success(pagedResponse, "لا توجد رحلات متاحة", 200);
                }

                return Response<PaginationPagedResponse<DashboardTripDTO>>.Success(pagedResponse, "تم استرجاع الرحلات بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<PaginationPagedResponse<DashboardTripDTO>>.Failure(null, $"حدث خطأ", 500);
            }
        }

    }

}
