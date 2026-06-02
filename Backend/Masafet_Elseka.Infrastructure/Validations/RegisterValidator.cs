using FluentValidation;
using Masafet_Elseka.Application.DTOs;

public class RegisterValidator : AbstractValidator<RegisterDTO>
{
    public RegisterValidator()
    {
        RuleFor(x => x.FullName)
            .NotEmpty().WithMessage("الاسم الكامل مطلوب.")
            .MaximumLength(100).WithMessage("الاسم الكامل يجب ألا يزيد عن 100 حرف.");

        RuleFor(x => x.Email)
    .NotEmpty().WithMessage("البريد الإلكتروني مطلوب.")
    .MaximumLength(100).WithMessage("البريد الإلكتروني طويل جدًا.")
    .Matches(@"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
    .WithMessage("صيغة البريد الإلكتروني غير صحيحة.");


        RuleFor(x => x.Phone)
            .NotEmpty().WithMessage("رقم الهاتف مطلوب.")
            .Matches(@"^(?:\+201|01)[0125]\d{8}$").WithMessage("رقم الهاتف يجب أن يكون رقم مصري صحيح.")
            .MaximumLength(13).WithMessage("رقم الهاتف يجب ألا يزيد عن 13 رقم.");

        RuleFor(x => x.Gender)
            .NotEmpty().WithMessage("النوع مطلوب.")
            .Must(g =>
                string.Equals(g, "ذكر", StringComparison.OrdinalIgnoreCase) ||
                string.Equals(g, "أنثى", StringComparison.OrdinalIgnoreCase) ||
                string.Equals(g, "male", StringComparison.OrdinalIgnoreCase) ||
                string.Equals(g, "female", StringComparison.OrdinalIgnoreCase))
            .WithMessage("النوع يجب أن يكون ذكر / أنثى أو Male / Female.");

        RuleFor(x => x.Role)
            .NotEmpty().WithMessage("الدور مطلوب.")
            .Must(role => new[] { "Client", "Dispatcher", "Accountant", "Driver" }.Contains(role))
            .WithMessage("الدور غير مسموح به.");

        RuleFor(x => x.NationalId)
            .Matches(@"^\d{14}$").When(x => !string.IsNullOrEmpty(x.NationalId))
            .WithMessage("رقم الهوية الوطنية يجب أن يتكون من 14 رقمًا صحيحًا.");

        RuleFor(x => x.DriverLicense)
            .MaximumLength(20).When(x => !string.IsNullOrEmpty(x.DriverLicense))
            .WithMessage("رقم رخصة السائق يجب ألا يتجاوز 20 حرفًا.");

        RuleFor(x => x.ScoterLicense)
            .MaximumLength(20).When(x => !string.IsNullOrEmpty(x.ScoterLicense))
            .WithMessage("رقم رخصة السكوتر يجب ألا يتجاوز 20 حرفًا.");

        RuleFor(x => x.Password)
            .NotEmpty().WithMessage("كلمة المرور مطلوبة.")
            .MinimumLength(6).WithMessage("كلمة المرور يجب ألا تقل عن 6 أحرف.");

        RuleFor(x => x.ConfirmPassword)
            .Equal(x => x.Password).WithMessage("كلمتا المرور غير متطابقتين.");

        RuleFor(x => x.ScoterType)
            .IsInEnum().When(x => x.ScoterType != null)
            .WithMessage("نوع السكوتر غير صحيح.");

        RuleFor(x => x.Photo)
            .Must(file => file == null || file.Length > 0)
            .WithMessage("الصورة غير صالحة.");
    }
}
