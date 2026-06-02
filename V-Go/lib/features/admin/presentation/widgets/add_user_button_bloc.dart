import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/cache/cache_helper.dart';
import '../../../../core/helpers/app_type.dart';
import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/upload_image_to_api.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/logic/user_cubit/user_cubit.dart';
import '../../../../core/utils/logic/user_cubit/user_state_extension.dart';
import '../../../../core/utils/widgets/custom_button.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../../auth/data/model/register_request_model.dart';

class AddUserButtonBlocConsumer extends StatelessWidget {
  const AddUserButtonBlocConsumer({
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.fullNameController,
    required this.formKey,
    required this.phoneController,
    required this.role,
    required this.selectedGender,
    required this.selectedImage,
    required this.nationalIdController,
    this.scooterType,
    this.driverLicense,
    this.scooterLicense,
    super.key,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final TextEditingController fullNameController;
  final TextEditingController phoneController;
  final TextEditingController? driverLicense;
  final TextEditingController? scooterLicense;
  final String selectedGender;
  final File? selectedImage;
  final TextEditingController nationalIdController;
  final GlobalKey<FormState> formKey;
  final String role;
  final int? scooterType;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UserCubit, UserState>(
      buildWhen: (previous, current) => _buildAndListenWhen(current),
      listenWhen: (previous, current) => _buildAndListenWhen(current),
      listener: (context, state) {
        if (state.status.isAddUserSuccess) {
          successToast(context, 'عملية ناجحة', state.successMessage);
          if (role == UserRole.accountant.capitalized ||
              role == UserRole.dispatcher.capitalized) {
            context.pop(result: true);
          } else {
            context.pushReplacementNamed(
              Routes.otpViewRoute,
              arguments: {
                'isForgetPassword': false,
                'email': emailController.text,
              },
            );
          }
        }
        if (state.status.isAddUserFailure) {
          errorToast(context, 'حدث خطا', state.errorMessage);
        }
      },
      builder: (context, state) {
        return state.status.isAddUserLoading
            ? const CustomLoadingWidget()
            : CustomButton(
                text: 'انشاء حساب',
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  _validateForm(context);
                },
              );
      },
    );
  }

  bool _buildAndListenWhen(UserState state) {
    return state.status.isAddUserLoading ||
        state.status.isAddUserFailure ||
        state.status.isAddUserSuccess;
  }

  _validateForm(BuildContext context) async {
    MultipartFile? imageFile;
    if (selectedImage != null) {
      imageFile = await uploadImageToApi(selectedImage!);
    }
    final registerRequestModel = RegisterRequestModel(
      email: emailController.text,
      password: passwordController.text,
      confirmPassword: confirmPasswordController.text,
      fullName: fullNameController.text,
      phone: phoneController.text,
      role: role,
      gender: selectedGender,
      imageProfile: imageFile,
      nationalId: nationalIdController.text,
      driverLicense: driverLicense?.text,
      scooterLicense: scooterLicense?.text,
      scooterType: scooterType,
      deviceType: deviceType(),
      fcmToken: CacheHelper.getString(AppConstants.fcmToken),
    );

    if (formKey.currentState!.validate() && context.mounted) {
      context.read<UserCubit>().addUser(registerRequestModel);
    }
  }
}
