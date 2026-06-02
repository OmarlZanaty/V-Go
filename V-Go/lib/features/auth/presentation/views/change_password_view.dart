import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

import '../../../../core/helpers/form_validator.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_text_field.dart';
import '../widgets/change_password_button.dart';

class ChangePasswordView extends StatefulWidget {
  const ChangePasswordView({super.key});

  @override
  State<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  late final TextEditingController _emailController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _oldPasswordController;
  late final GlobalKey<FormState> _formKey;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    _emailController = TextEditingController();
    _newPasswordController = TextEditingController();
    _oldPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _oldPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: 'تغيير كلمة المرور'),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    verticalSpace(20),
                    SlideInLeft(
                      from: 400,
                      child: CustomTextField(
                        controller: _emailController,
                        labelText: 'البريد الالكتروني',
                        validator: FormValidator.email,
                      ),
                    ),
                    verticalSpace(16),
                    SlideInLeft(
                      from: 400,
                      delay: const Duration(milliseconds: 100),
                      child: CustomTextField(
                        controller: _oldPasswordController,
                        labelText: 'كلمة المرور القديمة',
                        obscureText: true,
                      ),
                    ),
                    verticalSpace(16),
                    SlideInLeft(
                      from: 400,
                      delay: const Duration(milliseconds: 200),
                      child: CustomTextField(
                        controller: _newPasswordController,
                        labelText: 'كلمة المرور الجديدة',
                        validator: FormValidator.password,
                        obscureText: true,
                      ),
                    ),
                    Expanded(child: verticalSpace(40)),
                    SlideInUp(
                      from: 400,
                      delay: const Duration(milliseconds: 300),
                      child: ChangePasswordButton(
                        formKey: _formKey,
                        newPasswordController: _newPasswordController,
                        oldPasswordController: _oldPasswordController,
                        email: _emailController,
                      ),
                    ),
                    verticalSpace(20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
