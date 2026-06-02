using FluentValidation;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Validations
{
    public class UserValidator: AbstractValidator<ApplicationUser>
    {
        public UserValidator()
        {
            RuleFor(u => u.PhoneNumber)
                .NotEmpty()
                .WithMessage("رقم الهاتف مطلوب.")
                .Matches(@"^(?:\+201|01)[0125]\d{8}$")
                .MaximumLength(13)
                .WithMessage("رقم الهاتف يجب أن يتكون من 11 رقم صحيح.");

            RuleFor(u => u.NationalId)
                .MaximumLength(14).WithMessage("رقم الهوية الوطنية يجب ألا يتجاوز 14 رقمًا.")
                .Matches(@"^\d{14}$").WithMessage("رقم الهوية الوطنية يجب أن يتكون من 14 رقمًا صحيحًا.");

            RuleFor(u => u.License)
                .MaximumLength(20).WithMessage("يجب ألا يتجاوز رقم الرخصة 20 حرفًا.");
        }
    }
}
