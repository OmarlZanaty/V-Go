using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Expense
{
    public class ExpenseResponseDTO
    {
        public decimal TotalExpenses { get; set; }
        public List<ExpenseDTO>? Expenses { get; set; }
    }
}
