using CloudinaryDotNet.Actions;
using Masafet_Elseka.Application.DTOs.Statistics;
using Masafet_Elseka.Application.Interfaces.Statistics;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Masafet_Elseka.Infrastructure.Services.StatisticsService
{
    public class StatisticsService : IStatisticsService
    {
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly RoleManager<IdentityRole> _roleManager;
        private readonly Context _context;
        private readonly ILogger<StatisticsService> _logger;

        public StatisticsService(UserManager<ApplicationUser> userManager, Context context, RoleManager<IdentityRole> roleManager, ILogger<StatisticsService> logger)
        {
            _userManager = userManager;
            _context = context;
            _roleManager = roleManager;
            _logger = logger;
        }

        public async Task<Dictionary<string, string>> GetAdminDashboardStatistics()
        {
            try
            {
                var roles = await _roleManager.Roles.ToListAsync();
                if (roles == null || !roles.Any())
                {
                    return new Dictionary<string, string>
                    {
                        { "لا توجد أدوار في النظام", "0" }
                    };
                }

                var statistics = new Dictionary<string, string>();
                foreach (var role in roles)
                {
                    var roleUsers = await _userManager.GetUsersInRoleAsync(role.Name!);
                    var userCount = roleUsers.Count;
                    statistics.Add($"{role.Name!}s", userCount.ToString());
                }

                var tripsCount = await _context.Trips
                    .Where(t => t.Status == TripStatus.Completed)
                    .CountAsync();
                statistics.Add("Trips", tripsCount.ToString());
                var pricingRule = await _context.PricingRules.FirstOrDefaultAsync();
                if (pricingRule != null)
                {
                    statistics.Add("KilloPrice", pricingRule.PricePerKm.ToString());
                    statistics.Add("DriverCommission", pricingRule.DriverCommissionPercentage.ToString());
                }

                return statistics;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, ex.Message);
                return new Dictionary<string, string>
                {
                    { "حدث خطأ في النظام", "-1" }
                };
            }
        }

        public async Task<Response<AccountantStatisticsDto>> GetAccountantStatistics()
        {
            try
            {
                var today = DateTime.Today;

                int diff = ((int)today.DayOfWeek + 1) % 7;
                var startOfWeek = today.AddDays(-diff);
                var endOfWeek = startOfWeek.AddDays(7);

                var startOfMonth = new DateTime(today.Year, today.Month, 1);
                var endOfMonth = startOfMonth.AddMonths(1);

                var startOfQuarter = new DateTime(today.Year, ((today.Month - 1) / 3) * 3 + 1, 1);
                var endOfQuarter = startOfQuarter.AddMonths(3);

                var startOfHalfYear = today.Month <= 6
                    ? new DateTime(today.Year, 1, 1)
                    : new DateTime(today.Year, 7, 1);
                var endOfHalfYear = startOfHalfYear.AddMonths(6);

                var startOfYear = new DateTime(today.Year, 1, 1);
                var endOfYear = startOfYear.AddYears(1);

                var revenueQuery = _context.Trips.Where(t => t.Status == TripStatus.Completed);
                var expenseQuery = _context.Expenses.AsQueryable();

                async Task<FinancialSummaryDto> GetSummary(DateTime from, DateTime to)
                {
                    var pricingRule = await _context.PricingRules.FirstOrDefaultAsync();
                    var commissionPercentage = pricingRule != null ? pricingRule.DriverCommissionPercentage : 100;

                    var revenue = await revenueQuery
                        .Where(t => t.CreatedAt >= from && t.CreatedAt < to)
                        .SumAsync(t => (decimal)t.Price);
                    revenue = revenue * (100 - commissionPercentage) / 100;

                    var expenses = await expenseQuery
                        .Where(e => e.Date >= from && e.Date < to)
                        .SumAsync(e => (decimal)e.Cost);

                    return new FinancialSummaryDto
                    {
                        Revenue = revenue < 0 ? 0 : revenue,
                        Expenses = expenses
                    };
                }

                var result = new AccountantStatisticsDto
                {
                    Daily = await GetSummary(today, today.AddDays(1)),
                    Weekly = await GetSummary(startOfWeek, endOfWeek),
                    Monthly = await GetSummary(startOfMonth, endOfMonth),
                    Quarterly = await GetSummary(startOfQuarter, endOfQuarter),
                    SemiAnnually = await GetSummary(startOfHalfYear, endOfHalfYear),
                    Yearly = await GetSummary(startOfYear, endOfYear)
                };

                return Response<AccountantStatisticsDto>.Success(result, "تم جلب إحصائيات المحاسب بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<AccountantStatisticsDto>.Failure("حدث خطأ أثناء جلب الإحصائيات", 500, new List<string> { "حدث خطأ غير متوقع، يرجى المحاولة لاحقًا" });
            }
        }

        public async Task<Dictionary<string, object>> GetAdminWebDashboardStatistics()
        {
            try
            {
                var roles = await _roleManager.Roles.ToListAsync();
                if (roles == null || !roles.Any())
                {
                    return new Dictionary<string, object>
                    {
                        { "لا توجد أدوار في النظام", "0" }
                    };
                }

                var statistics = new Dictionary<string, object>();
                foreach (var role in roles)
                {
                    var roleUsers = await _userManager.GetUsersInRoleAsync(role.Name!);
                    var userCount = roleUsers.Count;
                    statistics.Add($"{role.Name!}s", userCount);                    
                }

                var tripsCount = await _context.Trips
                    .Where(t => t.Status == TripStatus.Completed)
                    .CountAsync();
                statistics.Add("totalTrips", tripsCount);

                var activeTripsCount = await _context.Trips
                    .Where(t => t.Status == TripStatus.InProgress || t.Status==TripStatus.Accepted || t.Status == TripStatus.Arrived)
                    .CountAsync();
                statistics.Add("activeTrips", activeTripsCount);

                var completedTripsTodayCount = await _context.Trips
                    .Where(t => t.Status == TripStatus.Completed && t.CreatedAt.Date == DateTime.Today)
                    .CountAsync();
                statistics.Add("completedTripsToday", completedTripsTodayCount);

                var newRegistrationsThisWeekCount = await _context.Users
                    .Where(u => u.CreatedAt >= DateTime.Today.AddDays(-7))
                    .CountAsync();
                statistics.Add("newRegistrations", newRegistrationsThisWeekCount);

                var pricingRule = await _context.PricingRules.FirstOrDefaultAsync();
                if (pricingRule != null)
                {
                    statistics.Add("kilometerPrice", pricingRule.PricePerKm);
                    statistics.Add("driverCommission", pricingRule.DriverCommissionPercentage);
                }

                var weeklyTripCounts = await _context.Trips
                    .Where(t => t.CreatedAt >= DateTime.Today.AddDays(-7) && t.Status!=TripStatus.Canceled
                        && t.Status != TripStatus.Rejected && t.Status != TripStatus.Pending)
                    .GroupBy(t => t.CreatedAt.Date)
                    .Select(g => new
                    {
                        Name = g.Key.Date.DayOfWeek.ToString(),
                        Rides = g.Count()
                    })
                    .ToListAsync();
                statistics.Add("weeklyRides", weeklyTripCounts);

                var commissionPercentage = pricingRule != null ? pricingRule.DriverCommissionPercentage : 0;
                var revenueLast5Months = await _context.Trips
                    .Where(t => t.Status == TripStatus.Completed && t.CreatedAt >= DateTime.Today.AddMonths(-5))
                    .GroupBy(t => new { t.CreatedAt.Year, t.CreatedAt.Month })
                    .Select(g => new
                    {
                        Month = new DateTime(g.Key.Year, g.Key.Month, 1).ToString("MMMM"),
                        Revenue = (g.Sum(t => (decimal?)t.Price) * ((100 - commissionPercentage) / 100)) ?? 0,
                    })
                    .ToListAsync();
                statistics.Add("monthlyRevenue", revenueLast5Months);

                return statistics;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, ex.Message);
                return new Dictionary<string, object>
                {
                    { "حدث خطأ في النظام", "-1" }
                };
            }
        }
    }
}