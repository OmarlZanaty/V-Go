import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

import '../../../../core/helpers/form_validator.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_text_field.dart';
import '../widgets/reset_password_button_bloc.dart';

class ResetPasswordView extends StatefulWidget {
  const ResetPasswordView({required this.email, super.key});
  final String email;

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmNewPasswordController;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _newPasswordController = TextEditingController();
    _confirmNewPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
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
                      delay: const Duration(milliseconds: 100),
                      child: CustomTextField(
                        controller: _newPasswordController,
                        labelText: 'كلمة المرور الجديدة',
                        validator: FormValidator.password,
                        obscureText: true,
                      ),
                    ),
                    verticalSpace(16),
                    SlideInLeft(
                      from: 400,
                      delay: const Duration(milliseconds: 200),
                      child: CustomTextField(
                        controller: _confirmNewPasswordController,
                        labelText: 'تأكيد كلمة المرور الجديدة',
                        validator: (value) => FormValidator.confirmPassword(
                          value,
                          originalPassword: _newPasswordController.text,
                        ),
                        obscureText: true,
                      ),
                    ),
                    Expanded(child: verticalSpace(40)),
                    SlideInUp(
                      from: 400,
                      delay: const Duration(milliseconds: 300),
                      child: ResetPasswordButtonBloc(
                        formKey: _formKey,
                        newPasswordController: _newPasswordController,
                        confirmNewPasswordController:
                            _confirmNewPasswordController,
                        email: widget.email,
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
