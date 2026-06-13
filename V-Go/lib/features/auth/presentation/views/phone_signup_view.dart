import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/get_route.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_button.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_text_field.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../logic/phone_auth_cubit/phone_auth_cubit.dart';

/// First-time sign-up for a new phone number: the user sets a password (saved as
/// the account password), then fills the rest of the profile (name, email,
/// gender). Reached only when the phone is NOT already registered.
class PhoneSignupView extends StatefulWidget {
  const PhoneSignupView({super.key, required this.phone});
  final String phone;

  @override
  State<PhoneSignupView> createState() => _PhoneSignupViewState();
}

class _PhoneSignupViewState extends State<PhoneSignupView> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String _gender = 'Male';

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: 'إنشاء حساب جديد'),
      body: BlocConsumer<PhoneAuthCubit, PhoneAuthState>(
        listener: (context, state) {
          if (state.status == PhoneAuthStatus.loginSuccess) {
            context.pushNamedAndRemoveUntil(
              getRoute(),
              predicate: (route) => false,
            );
          } else if (state.status == PhoneAuthStatus.failure) {
            errorToast(context, 'حدث خطأ', state.errorMessage);
          }
        },
        builder: (context, state) {
          final busy = state.status == PhoneAuthStatus.authenticating;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                verticalSpace(16),
                Text(
                  'رقم الهاتف: ${widget.phone}',
                  style: AppStyle.styleMedium14,
                ),
                verticalSpace(16),
                CustomTextField(
                  labelText: 'كلمة المرور',
                  controller: _passwordController,
                  obscureText: true,
                ),
                verticalSpace(16),
                CustomTextField(
                  labelText: 'تأكيد كلمة المرور',
                  controller: _confirmController,
                  obscureText: true,
                ),
                verticalSpace(16),
                CustomTextField(
                  labelText: 'الاسم بالكامل',
                  controller: _nameController,
                ),
                verticalSpace(16),
                CustomTextField(
                  labelText: 'البريد الإلكتروني (اختياري)',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                verticalSpace(16),
                Text('الجنس', style: AppStyle.styleMedium14),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        value: 'Male',
                        groupValue: _gender,
                        title: const Text('ذكر'),
                        activeColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setState(() => _gender = v!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        value: 'Female',
                        groupValue: _gender,
                        title: const Text('أنثى'),
                        activeColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setState(() => _gender = v!),
                      ),
                    ),
                  ],
                ),
                verticalSpace(24),
                busy
                    ? const CustomLoadingWidget()
                    : CustomButton(
                        text: 'إنشاء الحساب',
                        onPressed: () => _submit(context),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _submit(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    final password = _passwordController.text;
    if (password.length < 6) {
      errorToast(context, 'تنبيه', 'كلمة المرور يجب ألا تقل عن 6 أحرف.');
      return;
    }
    if (password != _confirmController.text) {
      errorToast(context, 'تنبيه', 'كلمتا المرور غير متطابقتين.');
      return;
    }
    final name = _nameController.text.trim();
    if (name.length < 2) {
      errorToast(context, 'تنبيه', 'يرجى إدخال الاسم.');
      return;
    }
    final email = _emailController.text.trim();
    context.read<PhoneAuthCubit>().register(
          password: password,
          fullName: name,
          email: email.isEmpty ? null : email,
          gender: _gender,
        );
  }
}
