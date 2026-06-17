using Microsoft.AspNetCore.Identity;

namespace Masafet_Elseka.Presentation.Identity
{
    /// <summary>
    /// Arabic messages for ASP.NET Identity validation errors (password policy,
    /// duplicate user/email, etc.) so the apps show them in Arabic.
    /// </summary>
    public class ArabicIdentityErrorDescriber : IdentityErrorDescriber
    {
        public override IdentityError PasswordTooShort(int length) => new()
        {
            Code = nameof(PasswordTooShort),
            Description = $"كلمة المرور يجب ألا تقل عن {length} أحرف."
        };

        public override IdentityError PasswordRequiresNonAlphanumeric() => new()
        {
            Code = nameof(PasswordRequiresNonAlphanumeric),
            Description = "كلمة المرور يجب أن تحتوي على رمز خاص واحد على الأقل."
        };

        public override IdentityError PasswordRequiresDigit() => new()
        {
            Code = nameof(PasswordRequiresDigit),
            Description = "كلمة المرور يجب أن تحتوي على رقم واحد على الأقل."
        };

        public override IdentityError PasswordRequiresLower() => new()
        {
            Code = nameof(PasswordRequiresLower),
            Description = "كلمة المرور يجب أن تحتوي على حرف إنجليزي صغير واحد على الأقل."
        };

        public override IdentityError PasswordRequiresUpper() => new()
        {
            Code = nameof(PasswordRequiresUpper),
            Description = "كلمة المرور يجب أن تحتوي على حرف إنجليزي كبير واحد على الأقل."
        };

        public override IdentityError PasswordRequiresUniqueChars(int uniqueChars) => new()
        {
            Code = nameof(PasswordRequiresUniqueChars),
            Description = $"كلمة المرور يجب أن تحتوي على {uniqueChars} أحرف مختلفة على الأقل."
        };

        public override IdentityError PasswordMismatch() => new()
        {
            Code = nameof(PasswordMismatch),
            Description = "كلمة المرور غير صحيحة."
        };

        public override IdentityError DuplicateUserName(string userName) => new()
        {
            Code = nameof(DuplicateUserName),
            Description = "هذا المستخدم مسجّل بالفعل."
        };

        public override IdentityError DuplicateEmail(string email) => new()
        {
            Code = nameof(DuplicateEmail),
            Description = "البريد الإلكتروني مستخدم بالفعل."
        };

        public override IdentityError InvalidEmail(string email) => new()
        {
            Code = nameof(InvalidEmail),
            Description = "البريد الإلكتروني غير صالح."
        };

        public override IdentityError InvalidUserName(string userName) => new()
        {
            Code = nameof(InvalidUserName),
            Description = "اسم المستخدم غير صالح."
        };

        public override IdentityError DefaultError() => new()
        {
            Code = nameof(DefaultError),
            Description = "حدث خطأ غير متوقع."
        };
    }
}
