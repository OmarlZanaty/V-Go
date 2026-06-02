using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Statistics
{
    public class DashboardStatisticsDTO
    {
        public decimal KmPrice { get; set; }
        public decimal DriverCommissionPercentage { get; set; }
        public int TotalClients { get; set; }
        public int TotalDrivers { get; set; }
        public int TotalAccountants { get; set; }
        public int TotalDispatchers { get; set; }
        public int TotalCompletedTrips { get; set; }
        public int TotalInProgressTrips { get; set; }
        public int TodayCompletedTrips { get; set; }

    }
}
