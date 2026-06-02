import 'dart:io';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

import '../../../../core/helpers/form_validator.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_text_field.dart';
import '../widgets/gender_radio_widget.dart';
import '../widgets/register_button_bloc.dart';
import '../widgets/user_image_section.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final GlobalKey<FormState> _formKey;
  String _selectedGender = 'male';
  File? _selectedImage;

  void _onImageSelected(File? image) {
    setState(() {
      _selectedImage = image;
    });
  }

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    _emailController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _passwordController = TextEditingController();
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: 'أنشاء حساب عميل'),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  verticalSpace(20),
                  SlideInDown(
                    from: 300,
                    child: UserImageSection(onImageSelected: _onImageSelected),
                  ),
                  verticalSpace(50),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SlideInLeft(
                          from: 400,
                          delay: const Duration(milliseconds: 80),
                          child: CustomTextField(
                            labelText: 'الاسم بالكامل',
                            controller: _fullNameController,
                            validator: FormValidator.name,
                          ),
                        ),
                        verticalSpace(14),
                        SlideInLeft(
                          from: 400,
                          delay: const Duration(milliseconds: 160),
                          child: CustomTextField(
                            labelText: 'رقم الهاتف',
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            validator: FormValidator.phone,
                          ),
                        ),
                        verticalSpace(14),
                        SlideInLeft(
                          from: 400,
                          delay: const Duration(milliseconds: 240),
                          child: CustomTextField(
                            labelText: 'البريد الإلكتروني',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: FormValidator.email,
                          ),
                        ),
                        verticalSpace(14),
                        SlideInLeft(
                          from: 400,
                          delay: const Duration(milliseconds: 320),
                          child: CustomTextField(
                            labelText: 'كلمة المرور',
                            controller: _passwordController,
                            validator: FormValidator.password,
                            obscureText: true,
                          ),
                        ),
                        verticalSpace(14),
                        SlideInLeft(
                          from: 400,
                          delay: const Duration(milliseconds: 400),
                          child: CustomTextField(
                            labelText: 'تأكيد كلمة المرور',
                            controller: _confirmPasswordController,
                            validator: (value) => FormValidator.confirmPassword(
                              value,
                              originalPassword: _passwordController.text,
                            ),
                            obscureText: true,
                          ),
                        ),
                        verticalSpace(18),
                        Text(
                          'الجنس :',
                          style: AppStyle.styleRegular14.copyWith(
                            color: AppColors.white,
                          ),
                        ),
                        verticalSpace(4),
                        SlideInLeft(
                          from: 400,
                          delay: const Duration(milliseconds: 480),
                          child: GenderRadioWidget(
                            groupValue: _selectedGender,
                            onGenderChanged: (value) {
                              setState(() {
                                _selectedGender = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: verticalSpace(40)),
                  SlideInUp(
                    from: 400,
                    delay: const Duration(milliseconds: 560),
                    child: RegisterButtonBlocConsumer(
                      emailController: _emailController,
                      passwordController: _passwordController,
                      confirmPasswordController: _confirmPasswordController,
                      fullNameController: _fullNameController,
                      phoneController: _phoneController,
                      gender: _selectedGender,
                      imageProfile: _selectedImage,
                      formKey: _formKey,
                    ),
                  ),

                  verticalSpace(20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
