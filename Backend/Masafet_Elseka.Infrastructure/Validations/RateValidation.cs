using FluentValidation;
using Masafet_Elseka.Domain.Entities;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Validations
{
    public class RateValidation:AbstractValidator<Rate>
    {
        public RateValidation()
        {
            RuleFor(r => r.Score)
                .InclusiveBetween(1, 5)
                .WithMessage("يجب أن يكون التقييم بين 1 و 5.");
            RuleFor(r => r.Comment)
                .MaximumLength(500)
                .WithMessage("يجب ألا يتجاوز التعليق 500 حرفًا.");
        }
    }
}
