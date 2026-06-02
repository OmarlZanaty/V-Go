import 'dart:io';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/form_validator.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_text_field.dart';
import '../../../auth/presentation/widgets/gender_radio_widget.dart';
import '../../../auth/presentation/widgets/user_image_section.dart';
import '../widgets/add_user_button_bloc.dart';
import '../widgets/scooter_type_radio_widget.dart';

class AddDriverView extends StatefulWidget {
  const AddDriverView({super.key});

  @override
  State<AddDriverView> createState() => _AddDriverViewState();
}

class _AddDriverViewState extends State<AddDriverView> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _nationalIdController;
  late final TextEditingController _licenseController;
  late final TextEditingController _scooterLicenseController;

  late final GlobalKey<FormState> _formKey;

  String _scooterType = ScooterType.electric.name;
  String _selectedGender = 'male';
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    _emailController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _passwordController = TextEditingController();
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
    _nationalIdController = TextEditingController();
    _licenseController = TextEditingController();
    _scooterLicenseController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _nationalIdController.dispose();
    _licenseController.dispose();
    _scooterLicenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: 'انشاء حساب سائق'),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  verticalSpace(10),
                  SlideInDown(
                    from: 300,
                    child: UserImageSection(
                      onImageSelected: (image) {
                        setState(() {
                          _selectedImage = image;
                        });
                      },
                    ),
                  ),
                  verticalSpace(30),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SlideInLeft(
                          from: 400,
                          delay: const Duration(milliseconds: 50),
                          child: CustomTextField(
                            labelText: 'الاسم بالكامل',
                            controller: _fullNameController,
                            validator: FormValidator.name,
                          ),
                        ),
                        verticalSpace(14),
                        SlideInLeft(
                          from: 400,
                          delay: const Duration(milliseconds: 100),
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
                          delay: const Duration(milliseconds: 150),
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
                          delay: const Duration(milliseconds: 200),
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
                          delay: const Duration(milliseconds: 250),
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
                        verticalSpace(14),
                        SlideInLeft(
                          from: 400,
                          delay: const Duration(milliseconds: 300),
                          child: CustomTextField(
                            labelText: 'الرقم القومي',
                            controller: _nationalIdController,
                            keyboardType: TextInputType.phone,
                            validator: FormValidator.nationalId,
                          ),
                        ),
                        verticalSpace(14),
                        SlideInLeft(
                          from: 400,
                          delay: const Duration(milliseconds: 350),
                          child: CustomTextField(
                            labelText: 'رقم الرخصة',
                            controller: _licenseController,
                            keyboardType: TextInputType.emailAddress,
                            validator: FormValidator.license,
                          ),
                        ),
                        verticalSpace(16),
                        Text(
                          'الجنس :',
                          style: AppStyle.styleRegular14.copyWith(
                            color: AppColors.white,
                          ),
                        ),
                        SlideInLeft(
                          from: 400,
                          delay: const Duration(milliseconds: 400),
                          child: GenderRadioWidget(
                            groupValue: _selectedGender,
                            onGenderChanged: (value) {
                              setState(() {
                                _selectedGender = value;
                              });
                            },
                          ),
                        ),
                        Text(
                          'نوع الاسكوتر :',
                          style: AppStyle.styleRegular14.copyWith(
                            color: AppColors.white,
                          ),
                        ),
                        SlideInLeft(
                          from: 400,
                          delay: const Duration(milliseconds: 450),
                          child: ScooterTypeRadioWidget(
                            scooterType: _scooterType,
                            onChanged: (value) {
                              setState(() {
                                _scooterType = value;
                              });
                            },
                          ),
                        ),
                        verticalSpace(14),
                        if (_scooterType == ScooterType.gasoline.name)
                          CustomTextField(
                            labelText: 'رقم رخصة الاسكوتر',
                            controller: _scooterLicenseController,
                            keyboardType: TextInputType.text,
                            validator: FormValidator.scooterLicense,
                          ),
                      ],
                    ),
                  ),
                  Expanded(child: verticalSpace(50)),
                  SlideInUp(
                    from: 400,
                    delay: const Duration(milliseconds: 500),
                    child: AddUserButtonBlocConsumer(
                      emailController: _emailController,
                      passwordController: _passwordController,
                      confirmPasswordController: _confirmPasswordController,
                      fullNameController: _fullNameController,
                      phoneController: _phoneController,
                      selectedGender: _selectedGender,
                      selectedImage: _selectedImage,
                      nationalIdController: _nationalIdController,
                      scooterLicense: _scooterType == 'gasoline'
                          ? _scooterLicenseController
                          : null,
                      scooterType: _scooterType == 'gasoline' ? 0 : 1,
                      driverLicense: _licenseController,
                      formKey: _formKey,
                      role: UserRole.driver.capitalized,
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
