import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../logic/phone_auth_cubit/phone_auth_cubit.dart';

/// Captain (driver) sign-up after phone verification — no password. Collects
/// name, optional email, national id, driver license, and scooter info.
class PhoneDriverSignupView extends StatefulWidget {
  const PhoneDriverSignupView({super.key, required this.phone});
  final String phone;

  @override
  State<PhoneDriverSignupView> createState() => _PhoneDriverSignupViewState();
}

class _PhoneDriverSignupViewState extends State<PhoneDriverSignupView> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _nationalId = TextEditingController();
  final _driverLicense = TextEditingController();
  final _scooterLicense = TextEditingController();
  String _gender = 'Male';
  int _scooterType = 0; // 0 = Gasoline, 1 = Electric

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _nationalId.dispose();
    _driverLicense.dispose();
    _scooterLicense.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.fillColored,
      title: Text(msg, style: AppStyle.body),
      autoCloseDuration: const Duration(seconds: 4),
      alignment: Alignment.bottomCenter,
    );
  }

  void _submit(PhoneAuthCubit cubit, String statePhone) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_name.text.trim().length < 2) return _toast('يرجى إدخال الاسم.');
    if (_scooterType == 0 && _scooterLicense.text.trim().isEmpty) {
      return _toast('يرجى إدخال رخصة السكوتر (بنزين).');
    }
    final fullName = _name.text.trim();
    final email = _email.text.trim().isEmpty ? null : _email.text.trim();
    final nationalId = _nationalId.text.trim().isEmpty ? null : _nationalId.text.trim();
    final driverLicense = _driverLicense.text.trim().isEmpty ? null : _driverLicense.text.trim();
    final scooterLicense = _scooterLicense.text.trim().isEmpty ? null : _scooterLicense.text.trim();

    if (statePhone.isEmpty) {
      // Came from Google sign-in (no phone number stored in state).
      cubit.registerDriverWithGoogle(
        fullName: fullName,
        email: email,
        gender: _gender,
        nationalId: nationalId,
        driverLicense: driverLicense,
        scooterType: _scooterType,
        scooterLicense: scooterLicense,
      );
    } else {
      cubit.registerDriver(
        fullName: fullName,
        email: email,
        gender: _gender,
        nationalId: nationalId,
        driverLicense: driverLicense,
        scooterType: _scooterType,
        scooterLicense: scooterLicense,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء حساب كابتن')),
      body: SafeArea(
        child: BlocConsumer<PhoneAuthCubit, PhoneAuthState>(
          listener: (context, state) {
            if (state.status == PhoneAuthStatus.loginSuccess) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                Routes.captainHomeViewRoute,
                (route) => false,
              );
            } else if (state.status == PhoneAuthStatus.verifyFailure) {
              _toast(state.errorMessage);
            }
          },
          builder: (context, state) {
            final busy = state.status == PhoneAuthStatus.verifying;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('رقم الهاتف: ${widget.phone}', style: AppStyle.hint),
                  SizedBox(height: 16.h),
                  _field(_name, 'الاسم بالكامل', Icons.person_outline),
                  SizedBox(height: 12.h),
                  _field(_email, 'البريد الإلكتروني (اختياري)',
                      Icons.email_outlined,
                      keyboard: TextInputType.emailAddress),
                  SizedBox(height: 12.h),
                  _field(_nationalId, 'الرقم القومي', Icons.badge_outlined,
                      keyboard: TextInputType.number),
                  SizedBox(height: 12.h),
                  _field(_driverLicense, 'رخصة القيادة', Icons.card_membership),
                  SizedBox(height: 12.h),
                  DropdownButtonFormField<int>(
                    value: _scooterType,
                    dropdownColor: AppColors.darkGrey,
                    style: AppStyle.body,
                    decoration: _decoration('نوع السكوتر', Icons.two_wheeler),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('بنزين')),
                      DropdownMenuItem(value: 1, child: Text('كهرباء')),
                    ],
                    onChanged: (v) => setState(() => _scooterType = v ?? 0),
                  ),
                  SizedBox(height: 12.h),
                  _field(_scooterLicense, 'رخصة السكوتر', Icons.confirmation_number_outlined),
                  SizedBox(height: 12.h),
                  Text('الجنس', style: AppStyle.hint),
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
                  SizedBox(height: 20.h),
                  SizedBox(
                    height: 52.h,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      onPressed: busy
                          ? null
                          : () => _submit(context.read<PhoneAuthCubit>(), state.phone),
                      child: busy
                          ? const SpinKitThreeBounce(
                              color: AppColors.black, size: 22)
                          : Text('إنشاء الحساب', style: AppStyle.button),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon,
      {TextInputType? keyboard}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      style: AppStyle.body,
      decoration: _decoration(hint, icon),
    );
  }

  InputDecoration _decoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppStyle.hint,
      prefixIcon: Icon(icon, color: AppColors.grey),
      filled: true,
      fillColor: AppColors.darkGrey,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide.none,
      ),
    );
  }
}
