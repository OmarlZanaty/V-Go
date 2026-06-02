import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

import '../../../../core/helpers/spacing.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_text_field.dart';
import '../widgets/forget_password_section.dart';
import '../widgets/google_login_button.dart';
import '../widgets/login_button_bloc.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: 'تسجيل الدخول'),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              children: [
                Image.asset('assets/images/b5.jpg'),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        SlideInLeft(
                          from: 400,
                          child: CustomTextField(
                            labelText: 'البريد الإلكتروني',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                        verticalSpace(16),
                        SlideInLeft(
                          from: 400,
                          delay: const Duration(milliseconds: 100),
                          child: CustomTextField(
                            labelText: 'كلمة المرور',
                            controller: _passwordController,
                            obscureText: true,
                          ),
                        ),
                        verticalSpace(10),
                        SlideInLeft(
                          from: 400,
                          delay: const Duration(milliseconds: 100),
                          child: const ForgetPasswordSection(),
                        ),
                        Expanded(child: verticalSpace(40)),
                        SlideInUp(
                          from: 400,
                          delay: const Duration(milliseconds: 250),
                          child: LoginButtonBloc(
                            emailController: _emailController,
                            passwordController: _passwordController,
                          ),
                        ),
                        verticalSpace(14),
                        SlideInUp(
                          from: 400,
                          delay: const Duration(milliseconds: 400),
                          child: const GoogleLoginButton(),
                        ),
                        verticalSpace(20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
