
using Masafet_Elseka.Application.DTOs.RevenueDto;
using Masafet_Elseka.Application.DTOs.Trip;
using Masafet_Elseka.Application.Interfaces.IAccountantService;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Data;
using Masafet_Elseka.Infrastructure.UOW;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Services.AccountatService
{
    public class AccountantService:IAccountantService
    {
        private readonly Context _context;
        private readonly IUnitOfWork _unitOfWork;
        public AccountantService(Context context, IUnitOfWork unitOfWork) { 
        
            _context = context;
            _unitOfWork = unitOfWork;
        }

        public async Task<Response<RevenueSummaryDto>> GetTotalRevenues()
        {
            try
            {
                var today = DateTime.Today;
                int diff = (7 + (int)today.DayOfWeek - (int)DayOfWeek.Saturday) % 7;
                var startOfWeek = today.AddDays(-diff);
                var endOfWeek = startOfWeek.AddDays(6);

                var baseQuery = _context.Trips
                    .Where(t => t.Status == TripStatus.Completed);


                var dailyRevenue = await baseQuery
                    .Where(t => t.CreatedAt.Date == today)
                    .SumAsync(t => t.Price);


                var weeklyRevenue = await baseQuery
                    .Where(t => t.CreatedAt.Date >= startOfWeek && t.CreatedAt.Date <= endOfWeek)
                    .SumAsync(t => t.Price);


                var monthlyRevenue = await baseQuery
                    .Where(t => t.CreatedAt.Month == today.Month && t.CreatedAt.Year == today.Year)
                    .SumAsync(t => t.Price);


                var yearlyRevenue = await baseQuery
                    .Where(t => t.CreatedAt.Year == today.Year)
                    .SumAsync(t => t.Price);

                var result = new RevenueSummaryDto
                {
                    DailyRevenue = dailyRevenue,
                    WeeklyRevenue = weeklyRevenue,
                    MonthlyRevenue = monthlyRevenue,
                    YearlyRevenue = yearlyRevenue
                };

                return Response<RevenueSummaryDto>.Success(result, "تم جلب الإيرادات بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<RevenueSummaryDto>.Failure("حدث خطأ غير متوقع، يرجى المحاولة لاحقًا", 500);
            }
        }




    }
}
