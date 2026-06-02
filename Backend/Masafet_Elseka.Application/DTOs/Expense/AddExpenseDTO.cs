using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Expense
{
    public class AddExpenseDTO
    {
        public double Cost { get; set; }
        public string Description { get; set; }
    }
}
