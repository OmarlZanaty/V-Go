using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Expense
{
    public class ExpenseDTO
    {
        public string Id { get; set; }
        public decimal Cost { get; set; }
        public string Description { get; set; }
        public DateTime Date { get; set; }
    }
}
