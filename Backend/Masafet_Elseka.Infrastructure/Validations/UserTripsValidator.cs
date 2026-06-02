using FluentValidation;
using Masafet_Elseka.Domain.Entities;

public class UserTripValidator : AbstractValidator<UserTrip>
{
    public UserTripValidator()
    {

        RuleFor(ut => ut.Date)
            .NotEmpty().WithMessage("تاريخ الرحلة مطلوب.")
            .LessThanOrEqualTo(DateTime.Now.ToEgyptTime()).WithMessage("تاريخ الرحلة لا يمكن أن يكون في المستقبل.");

        RuleFor(ut => ut.UserId)
            .NotEmpty().WithMessage("رقم المستخدم مطلوب.");

        RuleFor(ut => ut.TripId)
            .NotEmpty().WithMessage("رقم الرحلة مطلوب.");

        RuleFor(ut => ut.Role)
            .IsInEnum().WithMessage("دور المستخدم غير صالح.");

        RuleFor(ut => ut.IsApproved)
            .NotNull().WithMessage("حالة الموافقة مطلوبة.");
    }
}
