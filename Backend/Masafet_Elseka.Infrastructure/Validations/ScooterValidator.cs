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
    public class ScooterValidator:AbstractValidator<Scooter>
    {
        public ScooterValidator()
        {
            RuleFor(s => s.License)
                .NotEmpty().When(s => s.Type ==ScooterType.Gasoline)
                .WithMessage("يجب إدخال رقم الرخصة للدراجات التي تعمل بوقود.")
                .MaximumLength(20).WithMessage("يجب ألا يتجاوز رقم الرخصة 20 حرفًا.");
        }
    }
}
