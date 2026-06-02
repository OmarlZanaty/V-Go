using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Statistics
{
    public class AccountantStatisticsDto
    {
        public FinancialSummaryDto Daily { get; set; }
        public FinancialSummaryDto Weekly { get; set; }
        public FinancialSummaryDto Monthly { get; set; }
        public FinancialSummaryDto Quarterly { get; set; }
        public FinancialSummaryDto SemiAnnually { get; set; }
        public FinancialSummaryDto Yearly { get; set; }
    }
}
