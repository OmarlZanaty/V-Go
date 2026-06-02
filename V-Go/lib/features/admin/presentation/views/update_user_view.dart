import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/form_validator.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/model/user_model.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_text_field.dart';
import '../../../auth/presentation/widgets/gender_radio_widget.dart';
import '../../../auth/presentation/widgets/user_image_section.dart';
import '../widgets/scooter_type_radio_widget.dart';
import '../widgets/update_user_button.dart';

class UpdateUserView extends StatefulWidget {
  const UpdateUserView({required this.user, super.key});
  final UserModel user;
  @override
  State<UpdateUserView> createState() => _UpdateUserViewState();
}

class _UpdateUserViewState extends State<UpdateUserView> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  TextEditingController? _nationalIdController;
  TextEditingController? _licenseController;
  TextEditingController? _scooterLicenseController;
  File? _selectedImage;
  String? _selectedGender;
  String? _selectedScooterType;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    _fullNameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: widget.user.phoneNumber);
    if (widget.user.role == UserRole.driver.capitalized) {
      _nationalIdController = TextEditingController(
        text: widget.user.nationalId,
      );
      _licenseController = TextEditingController(text: widget.user.license);
      _scooterLicenseController = TextEditingController(
        text: widget.user.scooterLicense,
      );
      _selectedScooterType = widget.user.scooterType == 1
          ? ScooterType.electric.name
          : ScooterType.gasoline.name;
    }
    _selectedGender = widget.user.gender;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _nationalIdController?.dispose();
    _licenseController?.dispose();
    _scooterLicenseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: 'تعديل البيانات'),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    verticalSpace(10),
                    Align(
                      child: UserImageSection(
                        imageUrl: widget.user.profilePicture,
                        onImageSelected: (image) {
                          setState(() {
                            _selectedImage = image;
                          });
                        },
                      ),
                    ),
                    verticalSpace(35),
                    CustomTextField(
                      labelText: 'الاسم بالكامل',
                      controller: _fullNameController,
                      validator: FormValidator.name,
                    ),
                    verticalSpace(16),
                    CustomTextField(
                      labelText: 'رقم الهاتف',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      validator: FormValidator.phone,
                    ),
                    if (widget.user.role == UserRole.driver.capitalized) ...[
                      verticalSpace(16),
                      CustomTextField(
                        labelText: 'الرقم القومي',
                        controller: _nationalIdController!,
                        validator: FormValidator.nationalId,
                      ),
                    ],
                    verticalSpace(16),
                    Text(
                      'الجنس :',
                      style: AppStyle.styleRegular14.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                    verticalSpace(4),
                    GenderRadioWidget(
                      onGenderChanged: (groupValue) {
                        _selectedGender = groupValue;
                        setState(() {});
                      },
                      groupValue: _selectedGender!,
                    ),
                    if (widget.user.role == UserRole.driver.capitalized) ...[
                      const Divider(color: AppColors.darkGrey, height: 25),
                      verticalSpace(20),
                      CustomTextField(
                        labelText: 'رخصة القيادة',
                        controller: _licenseController!,
                        keyboardType: TextInputType.phone,
                        validator: FormValidator.license,
                      ),
                      if (_selectedScooterType == 'gasoline') ...[
                        verticalSpace(16),
                        CustomTextField(
                          labelText: 'رخصة السكوتر',
                          controller: _scooterLicenseController!,
                          keyboardType: TextInputType.phone,
                          validator: FormValidator.scooterLicense,
                        ),
                      ],
                      verticalSpace(16),
                      Text(
                        'نوع السكوتر :',
                        style: AppStyle.styleRegular14.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                      verticalSpace(4),
                      ScooterTypeRadioWidget(
                        scooterType: _selectedScooterType!,
                        onChanged: (value) {
                          _selectedScooterType = value;
                          setState(() {});
                        },
                      ),
                    ],
                    Expanded(child: verticalSpace(40)),
                    _updateButton(),
                    verticalSpace(20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  UpdateUserButton _updateButton() {
    return UpdateUserButton(
      formKey: _formKey,
      name: _fullNameController,
      phone: _phoneController,
      image: _selectedImage,
      nationalId: _nationalIdController,
      license: _licenseController,
      scooterLicense: _scooterLicenseController,
      gender: _selectedGender,
      userId: widget.user.id,
      scooterType: _selectedScooterType == ScooterType.electric.name
          ? 1
          : _selectedScooterType == ScooterType.gasoline.name
          ? 0
          : null,
    );
  }
}
