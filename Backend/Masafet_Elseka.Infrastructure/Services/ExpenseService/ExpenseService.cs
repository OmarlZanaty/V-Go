using Masafet_Elseka.Application.DTOs.Expense;
using Masafet_Elseka.Application.Interfaces.IExpenseService;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Infrastructure.Data;
using Masafet_Elseka.Infrastructure.UOW;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Services.ExpenseService
{
    public class ExpenseService : IExpenseService
    {
        private readonly Context _context;
        private readonly IUnitOfWork _unitOfWork;
        public ExpenseService(Context context, IUnitOfWork unitOfWork)
        {
            _context = context;
            _unitOfWork = unitOfWork;
        }

        public async Task<Response<object>> AddExpense(AddExpenseDTO model)
        {
            using var transaction = await _unitOfWork.BeginTransactionAsync();
            try
            {
                var validator = new Application.Validators.ExpenseValidator();
                var validationResult = await validator.ValidateAsync(model);
                if (!validationResult.IsValid)
                {
                    return Response<object>.Failure("هناك أخطاء في البيانات يرجى التحقق منها", 400,
                        validationResult.Errors.Select(e => e.ErrorMessage).ToList());
                }

                var expense = new Expense
                {
                    Id = Guid.NewGuid().ToString(),
                    Cost = model.Cost,
                    Description = model.Description,
                    Date = DateTime.Now.ToEgyptTime(),
                };

                await _unitOfWork.Expenses.AddAsync(expense);
                await _unitOfWork.SaveAsync();

                await transaction.CommitAsync();

                return Response<object>.Success(new { Id = expense.Id }, "تم إضافة المصروف بنجاح", 201);
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync();
                return Response<object>.Failure("حدث خطأ أثناء إضافة المصروف", 500, new List<string> { "حدث خطأ غير متوقع، يرجى المحاولة لاحقًا" });
            }
        }

        public async Task<Response<ExpenseResponseDTO>> GetAll(string? filter, int skip = 0, int take = 15)
        {
            try
            {
                var query = (await _unitOfWork.Expenses.GetAllAsync()).AsQueryable();

                if (!string.IsNullOrEmpty(filter))
                {
                    filter = filter.ToLower();
                    ApplyFilter(ref query, filter);
                }
                else
                {
                    query = query.Where(e => e.Date.Date == DateTime.Now.ToEgyptTime().Date);
                }

                var totalExpenses = (decimal)query.Sum(e => e.Cost);
                var expenses = query
                    .OrderByDescending(e => e.Date)
                    .Skip(skip)
                    .Take(take)
                    .Select(e => new ExpenseDTO
                    {
                        Id = e.Id,
                        Cost = (decimal)e.Cost,
                        Description = e.Description,
                        Date = e.Date,
                    })
                    .ToList();
                if(expenses.Count == 0)
                {
                    return Response<ExpenseResponseDTO>.Success(new ExpenseResponseDTO()
                    {
                        Expenses = new List<ExpenseDTO>(),
                        TotalExpenses = 0
                    }, "لا توجد مصروفات", 200);
                }

                return Response<ExpenseResponseDTO>.Success(new ExpenseResponseDTO
                {
                    Expenses = expenses,
                    TotalExpenses = totalExpenses
                }, "تم جلب المصروفات بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<ExpenseResponseDTO>.Failure(new ExpenseResponseDTO(), "حدث خطأ أثناء جلب المصروفات", 500, new List<string> { "حدث خطأ غير متوقع، يرجى المحاولة لاحقًا" });
            }
        }

        public async Task<Response<string>> DeleteExpense(string id)
        {
            try
            {
                var expense = await _unitOfWork.Expenses.GetByIdAsync(id);
                if (expense == null)
                {
                    return Response<string>.Failure("المصروف غير موجود", 404);
                }
                await _unitOfWork.Expenses.DeleteAsync(expense);
                await _unitOfWork.SaveAsync();
                return Response<string>.Success("تم حذف المصروف بنجاح", "تم حذف المصروف بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<string>.Failure("حدث خطأ أثناء حذف المصروف", 500, new List<string> { "حدث خطأ غير متوقع، يرجى المحاولة لاحقًا" });
            }
        }

        private void ApplyFilter(ref IQueryable<Expense> query, string filter)
        {
            switch (filter)
            {
                case "today":
                    query = query.Where(e => e.Date.Date == DateTime.Now.ToEgyptTime().Date);
                    break;
                case "lastweek":
                    query = query.Where(e => e.Date >= DateTime.Now.ToEgyptTime().AddDays(-7));
                    break;
                case "lastmonth":
                    query = query.Where(e => e.Date >= DateTime.Now.ToEgyptTime().AddMonths(-1));
                    break;
                case "lastyear":
                    query = query.Where(e => e.Date >= DateTime.Now.ToEgyptTime().AddYears(-1));
                    break;
                default:
                    query = query.Where(e => e.Date.Date == DateTime.Now.ToEgyptTime().Date);
                    break;
            }
        }
    }
}
