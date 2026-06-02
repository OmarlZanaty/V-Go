using FluentValidation;
using Masafet_Elseka.Domain.Entities;

public class MessageValidator : AbstractValidator<Message>
{
    public MessageValidator()
    {
        RuleFor(m => m.Id)
            .NotEmpty().WithMessage("معرّف الرسالة مطلوب.");

        RuleFor(m => m.Content)
            .NotEmpty().WithMessage("محتوى الرسالة مطلوب.")
            .MaximumLength(1000).WithMessage("محتوى الرسالة طويل جدًا (الحد الأقصى 1000 حرف).");

        RuleFor(m => m.SendAt)
            .NotEmpty().WithMessage("تاريخ ووقت الإرسال مطلوب.")
            .LessThanOrEqualTo(DateTime.Now.ToEgyptTime()).WithMessage("تاريخ الإرسال لا يمكن أن يكون في المستقبل.");

        RuleFor(m => m.UserId)
            .NotEmpty().WithMessage("المستخدم المرسل مطلوب.");

        RuleFor(m => m.ChatId)
            .NotEmpty().WithMessage("معرّف المحادثة مطلوب.");
    }
}
