import 'dart:io';

import 'app_regex.dart';

class FormValidator {
  const FormValidator._();

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'الاسم مطلوب';
    }
    if (value.trim().length < 2) {
      return 'الاسم قصير جداً (2 أحرف على الأقل)';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'رقم الهاتف مطلوب';
    }
    final cleaned = value.trim().replaceAll(RegExp(r'\D'), '');
    if (!AppRegex.isPhoneNumberValid(cleaned)) {
      return 'رقم الهاتف يجب أن يبدأ بـ 010/011/012/015 ويتكون من 11 رقم';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'البريد الإلكتروني مطلوب';
    }
    if (!AppRegex.isEmailValid(value.trim())) {
      return 'أدخل بريدًا إلكترونيًا صحيحًا';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'كلمة المرور مطلوبة';
    }

    
      final errors = <String>[];

      if (!AppRegex.hasMinLength(value)) errors.add('• 6 أحرف على الأقل');
      if (!AppRegex.hasLowerCase(value)) {
        errors.add('• حرف صغير واحد على الأقل');
      }
      if (!AppRegex.hasUpperCase(value)) {
        errors.add('• حرف كبير واحد على الأقل');
      }
      if (!AppRegex.hasNumber(value)) {
        errors.add('• رقم واحد على الأقل');
      }
      if (!AppRegex.hasSpecialCharacter(value)) {
        errors.add("• رمز خاص واحد على الأقل (@\$!%*?&)");
      }
      return errors.isEmpty ? null : 'كلمة المرور ضعيفة:\n${errors.join('\n')}';
  }

  static String? confirmPassword(String? value, {String? originalPassword}) {
    if (value == null || value.isEmpty) {
      return 'تأكيد كلمة المرور مطلوب';
    }
    if (value != originalPassword) {
      return 'كلمتا المرور غير متطابقتين';
    }
    return null;
  }

  static String? nationalId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'الرقم القومي مطلوب';
    }
    final cleaned = value.trim().replaceAll(RegExp(r'\D'), '');
    if (!AppRegex.isNationalIdValid(cleaned)) {
      return 'رقم القومي يجب أن يكون 14 رقم';
    }
    return null;
  }

  static String? license(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'رقم الرخصة مطلوب';
    }
    return null;
  }

  static String? scooterLicense(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'رخصة الاسكوتر مطلوبة';
    }
    return null;
  }

  static String? gender(String? value) {
    if (value == null || value.isEmpty) {
      return 'الجنس مطلوب';
    }
    return null;
  }

  static String? scooterType(int? value) {
    if (value == null) {
      return 'نوع السكوتر مطلوب';
    }
    return null;
  }

  static String? image(File? file) {
    if (file == null) {
      return 'صورة الملف الشخصي مطلوبة';
    }
    // Optional: size check (≤ 5 MB)
    final bytes = file.lengthSync();
    if (bytes > 5 * 1024 * 1024) {
      return 'حجم الصورة يجب ألا يتجاوز 5 ميغابايت';
    }
    return null;
  }

  // static bool validateFullForm({
  //   required GlobalKey<FormState> formKey,
  //   required String? gender,
  //   int? scooterType,
  //   File? image,
  //   TextEditingController? nationalId,
  //   TextEditingController? license,
  //   TextEditingController? scooterLicense,
  //   // Password fields (optional)
  //   TextEditingController? password,
  //   TextEditingController? confirmPassword,
  // }) {
  //   // 1. Form-level validation
  //   if (!formKey.currentState!.validate()) return false;

  //   // 2. Non-TextFormField fields
  //   final genderError = FormValidator.gender(gender);
  //   final scooterError = scooterType != null ? FormValidator.scooterType(scooterType) : null;
  //   final imageError = image != null ? FormValidator.image(image) : null;

  //   final error = genderError ?? scooterError ?? imageError;
  //   if (error != null) {
  //     debugPrint('Validation error: $error');
  //     return false;
  //   }

  //   // 3. Optional TextFormFields
  //   if (nationalId != null && FormValidator.nationalId(nationalId.text) != null) return false;
  //   if (license != null && FormValidator.license(license.text) != null) return false;
  //   if (scooterLicense != null && FormValidator.scooterLicense(scooterLicense.text) != null) return false;

  //   // 4. Password validation (if provided)
  //   if (password != null) {
  //     final pwdError = FormValidator.password(password.text);
  //     if (pwdError != null) {
  //       debugPrint('Password error: $pwdError');
  //       return false;
  //     }
  //     if (confirmPassword != null) {
  //       final confirmError = FormValidator.confirmPassword(
  //         confirmPassword.text,
  //         password.text,
  //       );
  //       if (confirmError != null) {
  //         debugPrint('Confirm password error: $confirmError');
  //         return false;
  //       }
  //     }
  //   }

  //   return true;
  // }
}
