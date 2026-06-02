using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Pagination
{
    public class QueryParameters
    {
        public string? Search { get; set; }
        public string? Gender { get; set; }

        //for drivers
        public string? ScooterType { get; set; }

    }
}
