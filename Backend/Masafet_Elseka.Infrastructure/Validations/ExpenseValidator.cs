using FluentValidation;
using Masafet_Elseka.Application.DTOs.Expense;
using Masafet_Elseka.Domain.Entities;

namespace Masafet_Elseka.Application.Validators
{
    public class ExpenseValidator : AbstractValidator<AddExpenseDTO>
    {
        public ExpenseValidator()
        {

            RuleFor(x => x.Cost)
                .GreaterThan(0).WithMessage("Cost must be greater than 0.");

            RuleFor(x => x.Description)
                .NotEmpty().WithMessage("Description is required.")
                .MaximumLength(250).WithMessage("Description must not exceed 250 characters.");

        }
    }
}
