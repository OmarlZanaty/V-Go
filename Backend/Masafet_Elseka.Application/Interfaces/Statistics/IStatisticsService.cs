using Masafet_Elseka.Application.DTOs.Statistics;
using Masafet_Elseka.Application.Response;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.Interfaces.Statistics
{
    public interface IStatisticsService
    {
        public Task<Dictionary<string, string>> GetAdminDashboardStatistics();
        public Task<Dictionary<string, object>> GetAdminWebDashboardStatistics();
        public Task<Response<AccountantStatisticsDto>> GetAccountantStatistics();
        //public Task<Response<DashboardStatisticsDTO>> GetDashboardStatistics();
    }
}
