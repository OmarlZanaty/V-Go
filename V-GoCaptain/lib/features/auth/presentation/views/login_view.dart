import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../logic/cubit/auth_cubit.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (_formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      context.read<AuthCubit>().login(
            email: _emailController.text,
            password: _passwordController.text,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is LoginSuccess) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                Routes.captainHomeViewRoute,
                (route) => false,
              );
            } else if (state is AuthError) {
              toastification.show(
                context: context,
                type: ToastificationType.error,
                style: ToastificationStyle.fillColored,
                title: Text(state.message, style: AppStyle.body),
                autoCloseDuration: const Duration(seconds: 4),
                alignment: Alignment.bottomCenter,
              );
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthLoading;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset('assets/images/v-go-logo.png',
                          height: 110.h, fit: BoxFit.contain),
                      SizedBox(height: 12.h),
                      Text('V-Go Captain',
                          textAlign: TextAlign.center, style: AppStyle.heading),
                      SizedBox(height: 6.h),
                      Text('سجّل دخولك لبدء استقبال الرحلات',
                          textAlign: TextAlign.center, style: AppStyle.hint),
                      SizedBox(height: 32.h),
                      _emailField(),
                      SizedBox(height: 16.h),
                      _passwordField(),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => Navigator.of(context)
                              .pushNamed(Routes.resetPasswordViewRoute),
                          child: Text('نسيت كلمة المرور؟',
                              style: AppStyle.hint
                                  .copyWith(color: AppColors.primary)),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      _loginButton(context, isLoading),
                      SizedBox(height: 16.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('ليس لديك حساب؟', style: AppStyle.hint),
                          TextButton(
                            onPressed: () => Navigator.of(context)
                                .pushNamed(Routes.registerViewRoute),
                            child: Text('سجّل ككابتن',
                                style: AppStyle.body
                                    .copyWith(color: AppColors.primary)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _emailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: AppStyle.body,
      decoration: _decoration('البريد الإلكتروني', Icons.email_outlined),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'أدخل البريد الإلكتروني';
        if (!v.contains('@')) return 'بريد إلكتروني غير صالح';
        return null;
      },
    );
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscure,
      style: AppStyle.body,
      decoration: _decoration('كلمة المرور', Icons.lock_outline).copyWith(
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
              color: AppColors.grey),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      validator: (v) =>
          (v == null || v.isEmpty) ? 'أدخل كلمة المرور' : null,
    );
  }

  Widget _loginButton(BuildContext context, bool isLoading) {
    return SizedBox(
      height: 52.h,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
        onPressed: isLoading ? null : () => _submit(context),
        child: isLoading
            ? const SpinKitThreeBounce(color: AppColors.black, size: 22)
            : Text('تسجيل الدخول', style: AppStyle.button),
      ),
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
