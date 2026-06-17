using Masafet_Elseka.Application.DTOs.Rating;
using Masafet_Elseka.Application.Interfaces.INotificationService;
using Masafet_Elseka.Application.Interfaces.IRatingService;
using Masafet_Elseka.Application.Interfaces.User;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Services.RatingService
{
    public class RatingService: IRatingService
    {
        private readonly Context _context;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly IServiceProvider _serviceProvider;
        private readonly INotificationService _notificationService;

        public RatingService(Context context, UserManager<ApplicationUser> userManager, IServiceProvider serviceProvider, INotificationService notificationService)
        {
            _context = context;
            _userManager = userManager;
            _serviceProvider = serviceProvider;
            _notificationService = notificationService;
        }

        public async Task<Response<RatingResponseDTO>> AddRateAsync(RatingDTO rate)
        {
            try
            {
                var trip = await _context.Trips.AsNoTracking()
                    .Include(t => t.UserTrips)
                    .FirstOrDefaultAsync(t => t.Id == rate.TripId);

                if (trip == null)
                    return Response<RatingResponseDTO>.Failure("الرحلة غير موجودة", 404);

                if (!trip.UserTrips.Any(ut => ut.UserId == rate.FromUserId)
                    || !trip.UserTrips.Any(ut => ut.UserId == rate.ToUserId))
                {
                    return Response<RatingResponseDTO>.Failure("أحد المستخدمين (السائق أو العميل) ليس طرفًا في هذه الرحلة", 400);
                }

                var existingRate = await _context.Rates
                    .FirstOrDefaultAsync(r => r.TripId == rate.TripId && r.FromUserId == rate.FromUserId);

                if (existingRate != null)
                    return Response<RatingResponseDTO>.Failure("لقد قمت بتقييم هذا المستخدم لهذه الرحلة من قبل", 400);

                var newRate = new Rate
                {
                    Id = Guid.NewGuid().ToString(),
                    Score = rate.Score,
                    Comment = rate.Comment!,
                    TripId = rate.TripId,
                    FromUserId = rate.FromUserId,
                    ToUserId = rate.ToUserId,
                    Timestamp = DateTime.Now.ToEgyptTime()
                };

                _context.Rates.Add(newRate);
                await _context.SaveChangesAsync();

                var fromUserRole = trip.UserTrips.FirstOrDefault(ut => ut.UserId == rate.FromUserId)?.Role;
                var toUserRole = trip.UserTrips.FirstOrDefault(ut => ut.UserId == rate.ToUserId)?.Role;

                string title;
                string message;

                if (fromUserRole == UserTripRole.Client && toUserRole == UserTripRole.Driver)
                {
                    title = "تقييم جديد من عميل";
                    message = $"لقد تلقيت تقييمًا جديدًا بواقع {rate.Score} نجوم من أحد العملاء عن رحلتك.";
                }
                else if (fromUserRole == UserTripRole.Driver && toUserRole == UserTripRole.Client)
                {
                    title = "تقييم جديد من السائق";
                    message = $"لقد تلقيت تقييمًا جديدًا بواقع {rate.Score} نجوم من السائق عن رحلتك.";
                }
                else
                {
                    title = "تقييم جديد";
                    message = $"لقد تلقيت تقييمًا جديدًا بواقع {rate.Score} نجوم.";
                }

                var toUser = await _userManager.FindByIdAsync(rate.ToUserId);
                if (toUser != null)
                {
                    await _notificationService.SendNotificationToUserWithSavingAsync(
                        toUser.Id,
                        title,
                        message
                    );
                }

                return Response<RatingResponseDTO>.Success(
                    new RatingResponseDTO
                    {
                        Score = newRate.Score,
                        Comment = newRate.Comment,
                    },
                    "تم التقييم بنجاح",
                    201
                );
            }
            catch (Exception ex)
            {
                return Response<RatingResponseDTO>.Failure("حدث خطأ أثناء إضافة التقييم: " + "حدث خطأ غير متوقع، يرجى المحاولة لاحقًا", 500);
            }
        }


        public async Task<Response<ICollection<RatingResponseDTO>>> GetUserRates(string userId)
        {
            try
            {
                var user=await _userManager.FindByIdAsync(userId);
                if(user==null)
                {
                    return Response<ICollection<RatingResponseDTO>>.Failure("المستخدم غير موجود",404);
                }

                var rates = await _context.Rates
                    .AsNoTracking()
                    .Where(r => r.ToUserId == userId)
                    .Select(r => new RatingResponseDTO
                    {
                        Score = r.Score,
                        Comment = r.Comment,
                    })
                    .ToListAsync();

                if (rates == null || rates.Count == 0)
                    return Response<ICollection<RatingResponseDTO>>.Success(new List<RatingResponseDTO>(), "لا توجد تقييمات لهذا المستخدم",201);

                return Response<ICollection<RatingResponseDTO>>.Success(rates, "تم جلب التقييمات بنجاح",200);
            }
            catch (Exception ex)
            {
                return Response<ICollection<RatingResponseDTO>>.Failure("حدث خطأ أثناء جلب التقييمات: " + "حدث خطأ غير متوقع، يرجى المحاولة لاحقًا",500);
            }
        }

        public async Task<decimal> GetAverageRate(string userId)
        {
            try
            {
                var rates = await _context.Rates.AsNoTracking()
                    .Where(r => r.ToUserId == userId)
                    .Select(r => r.Score).ToListAsync();
                if (rates == null || !rates.Any())
                {
                    return 0;
                }
                return (decimal)Math.Round(rates.Average(), 1);
            }
            catch
            {
                return 0;
            }
        }

        public async Task<Dictionary<string, decimal>> GetAverageRatesFor(IEnumerable<string> userIds)
        {
            try
            {
                var ids = userIds.Where(id => !string.IsNullOrEmpty(id)).Distinct().ToList();
                if (ids.Count == 0)
                    return new Dictionary<string, decimal>();

                var grouped = await _context.Rates.AsNoTracking()
                    .Where(r => ids.Contains(r.ToUserId))
                    .GroupBy(r => r.ToUserId)
                    .Select(g => new { UserId = g.Key, Avg = g.Average(x => x.Score) })
                    .ToListAsync();

                return grouped.ToDictionary(x => x.UserId, x => (decimal)Math.Round(x.Avg, 1));
            }
            catch
            {
                return new Dictionary<string, decimal>();
            }
        }

        public async Task<ICollection<RatingResponseDTO>> GetCurrentUserTripRates()
        {
            try
            {
                var userService=_serviceProvider.GetRequiredService<IUserService>();
                var user = await userService.GetCurrentUserAsync();
                if (user == null)
                {
                    return new List<RatingResponseDTO>();
                }
                var rates = await _context.Rates
                    .AsNoTracking()
                    .Where(r => r.ToUserId == user.Id)
                    .Select(r => new RatingResponseDTO
                    {
                        Score = r.Score,
                        Comment = r.Comment,
                    })
                    .ToListAsync();

                return rates.Any() ? rates : new List<RatingResponseDTO>();
            }
            catch (Exception ex)
            {
                return new List<RatingResponseDTO>();
            }
        }

    }
}
