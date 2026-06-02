using Masafet_Elseka.Application.DTOs.Expense;
using Masafet_Elseka.Application.Response;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.Interfaces.IExpenseService
{
    public interface IExpenseService
    {
        public Task<Response<object>> AddExpense(AddExpenseDTO model);
        public Task<Response<ExpenseResponseDTO>> GetAll(string? filter, int skip=0, int take=15);
        public Task<Response<string>> DeleteExpense(string id);
    }
}
