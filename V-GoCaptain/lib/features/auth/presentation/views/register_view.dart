import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../data/model/register_request_model.dart';
import '../logic/cubit/auth_cubit.dart';
import '../widgets/auth_text_field.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _nationalId = TextEditingController();
  final _driverLicense = TextEditingController();
  final _scooterLicense = TextEditingController();

  String _gender = 'male';
  String _scooterType = 'electric'; // gasoline | electric
  File? _photo;

  @override
  void dispose() {
    for (final c in [
      _name, _email, _phone, _password, _confirm,
      _nationalId, _driverLicense, _scooterLicense,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _submit(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_photo == null) {
      _toast(context, 'برجاء إضافة صورة شخصية');
      return;
    }
    FocusScope.of(context).unfocus();
    final isGasoline = _scooterType == 'gasoline';
    final model = RegisterRequestModel(
      fullName: _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      gender: _gender,
      role: 'Driver',
      password: _password.text,
      confirmPassword: _confirm.text,
      nationalId: _nationalId.text.trim(),
      driverLicense: _driverLicense.text.trim(),
      scooterLicense: isGasoline ? _scooterLicense.text.trim() : null,
      scooterType: isGasoline ? 0 : 1,
      imageProfile: await MultipartFile.fromFile(_photo!.path),
      deviceType: 'Android',
    );
    if (context.mounted) context.read<AuthCubit>().register(model);
  }

  void _toast(BuildContext context, String msg, {bool error = true}) {
    toastification.show(
      context: context,
      type: error ? ToastificationType.error : ToastificationType.success,
      style: ToastificationStyle.fillColored,
      title: Text(msg, style: AppStyle.body),
      autoCloseDuration: const Duration(seconds: 4),
      alignment: Alignment.bottomCenter,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تسجيل كابتن جديد',
          style: AppStyle.title.copyWith(color: AppColors.black))),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is RegisterSuccess) {
            _toast(context, 'تم إرسال رمز التحقق إلى بريدك', error: false);
            Navigator.of(context).pushNamed(
              Routes.otpViewRoute,
              arguments: {'email': state.email, 'type': 'Register'},
            );
          } else if (state is AuthError) {
            _toast(context, state.message);
          }
        },
        builder: (context, state) {
          final loading = state is AuthLoading;
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: _photoPicker()),
                  SizedBox(height: 20.h),
                  AuthTextField(controller: _name, hint: 'الاسم بالكامل',
                      icon: Icons.person_outline,
                      validator: (v) => (v==null||v.trim().isEmpty) ? 'أدخل الاسم' : null),
                  SizedBox(height: 14.h),
                  AuthTextField(controller: _email, hint: 'البريد الإلكتروني',
                      icon: Icons.email_outlined, keyboard: TextInputType.emailAddress,
                      validator: (v) => (v==null||!v.contains('@')) ? 'بريد غير صالح' : null),
                  SizedBox(height: 14.h),
                  AuthTextField(controller: _phone, hint: 'رقم الهاتف',
                      icon: Icons.phone_outlined, keyboard: TextInputType.phone,
                      validator: (v) => (v==null||v.trim().length < 8) ? 'رقم غير صالح' : null),
                  SizedBox(height: 14.h),
                  _genderRow(),
                  SizedBox(height: 14.h),
                  AuthTextField(controller: _password, hint: 'كلمة المرور',
                      icon: Icons.lock_outline, obscure: true,
                      validator: (v) => (v==null||v.length < 6) ? '6 أحرف على الأقل' : null),
                  SizedBox(height: 14.h),
                  AuthTextField(controller: _confirm, hint: 'تأكيد كلمة المرور',
                      icon: Icons.lock_outline, obscure: true,
                      validator: (v) => v != _password.text ? 'غير متطابقة' : null),
                  const Divider(color: AppColors.grey, height: 32),
                  AuthTextField(controller: _nationalId, hint: 'الرقم القومي',
                      icon: Icons.badge_outlined, keyboard: TextInputType.number,
                      validator: (v) => (v==null||v.trim().isEmpty) ? 'أدخل الرقم القومي' : null),
                  SizedBox(height: 14.h),
                  AuthTextField(controller: _driverLicense, hint: 'رخصة القيادة',
                      icon: Icons.contact_mail_outlined,
                      validator: (v) => (v==null||v.trim().isEmpty) ? 'أدخل رخصة القيادة' : null),
                  SizedBox(height: 14.h),
                  _scooterTypeRow(),
                  if (_scooterType == 'gasoline') ...[
                    SizedBox(height: 14.h),
                    AuthTextField(controller: _scooterLicense, hint: 'رخصة السكوتر',
                        icon: Icons.two_wheeler_outlined,
                        validator: (v) => (v==null||v.trim().isEmpty) ? 'أدخل رخصة السكوتر' : null),
                  ],
                  SizedBox(height: 28.h),
                  SizedBox(
                    height: 52.h,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r)),
                      ),
                      onPressed: loading ? null : () => _submit(context),
                      child: loading
                          ? const SpinKitThreeBounce(color: AppColors.black, size: 22)
                          : Text('إنشاء الحساب', style: AppStyle.button),
                    ),
                  ),
                  SizedBox(height: 12.h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _photoPicker() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: CircleAvatar(
        radius: 50.r,
        backgroundColor: AppColors.darkGrey,
        backgroundImage: _photo != null ? FileImage(_photo!) : null,
        child: _photo == null
            ? Icon(Icons.add_a_photo_outlined, color: AppColors.grey, size: 28.r)
            : null,
      ),
    );
  }

  Widget _genderRow() {
    return Row(
      children: [
        Text('النوع:', style: AppStyle.body),
        Expanded(child: _radio('male', 'ذكر', _gender, (v) => setState(() => _gender = v))),
        Expanded(child: _radio('female', 'أنثى', _gender, (v) => setState(() => _gender = v))),
      ],
    );
  }

  Widget _scooterTypeRow() {
    return Row(
      children: [
        Text('السكوتر:', style: AppStyle.body),
        Expanded(child: _radio('electric', 'كهربائي', _scooterType, (v) => setState(() => _scooterType = v))),
        Expanded(child: _radio('gasoline', 'بنزين', _scooterType, (v) => setState(() => _scooterType = v))),
      ],
    );
  }

  Widget _radio(String value, String label, String group, ValueChanged<String> onChanged) {
    return InkWell(
      onTap: () => onChanged(value),
      child: Row(
        children: [
          RadioGroup<String>(
            groupValue: group,
            onChanged: (v) => onChanged(v!),
            child: Radio<String>(
              value: value,
              activeColor: AppColors.primary,
            ),
          ),
          Flexible(child: Text(label, style: AppStyle.body)),
        ],
      ),
    );
  }
}
