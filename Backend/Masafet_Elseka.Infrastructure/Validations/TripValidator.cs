using FluentValidation;
using Masafet_Elseka.Domain.Entities;

public class TripValidator : AbstractValidator<Trip>
{
    public TripValidator()
    {
        

        RuleFor(t => t.Price)
            .GreaterThanOrEqualTo(0).WithMessage("يجب أن يكون السعر رقمًا موجبًا أو صفر.");

        RuleFor(t => t.StartLat)
     .NotEmpty().WithMessage("موقع الانطلاق مطلوب.")
     .LessThanOrEqualTo(90).WithMessage("قيمة خط العرض غير صحيحة.")
     .GreaterThanOrEqualTo(-90).WithMessage("قيمة خط العرض غير صحيحة.");

        RuleFor(t => t.StartLng)
            .NotEmpty().WithMessage("موقع الانطلاق مطلوب.")
            .LessThanOrEqualTo(180).WithMessage("قيمة خط الطول غير صحيحة.")
            .GreaterThanOrEqualTo(-180).WithMessage("قيمة خط الطول غير صحيحة.");

        RuleFor(t => t.EndLat)
            .NotEmpty().WithMessage("موقع الوصول مطلوب.")
            .LessThanOrEqualTo(90).WithMessage("قيمة خط العرض غير صحيحة.")
            .GreaterThanOrEqualTo(-90).WithMessage("قيمة خط العرض غير صحيحة.");

        RuleFor(t => t.EndLng)
            .NotEmpty().WithMessage("موقع الوصول مطلوب.")
            .LessThanOrEqualTo(180).WithMessage("قيمة خط الطول غير صحيحة.")
            .GreaterThanOrEqualTo(-180).WithMessage("قيمة خط الطول غير صحيحة.");


        RuleFor(t => t.CreatedAt)
            .NotEmpty().WithMessage("تاريخ الإنشاء مطلوب.")
            .LessThanOrEqualTo(DateTime.Now.ToEgyptTime()).WithMessage("تاريخ الإنشاء لا يمكن أن يكون في المستقبل.");

        RuleFor(t => t.Status)
            .IsInEnum().WithMessage("حالة الرحلة غير صالحة.");

        RuleFor(t => new { t.StartLat, t.StartLng })
        .Must(pos => !(pos.StartLat == 0 && pos.StartLng == 0))
        .WithMessage("إحداثيات الموقع غير صحيحة.");

    }
}
