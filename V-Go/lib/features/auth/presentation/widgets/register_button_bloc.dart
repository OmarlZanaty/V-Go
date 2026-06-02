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
import '../../../../core/utils/widgets/custom_button.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../data/model/register_request_model.dart';
import '../logic/cubit/auth_cubit.dart';
import '../logic/cubit/auth_state_extension.dart';

class RegisterButtonBlocConsumer extends StatelessWidget {
  const RegisterButtonBlocConsumer({
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.fullNameController,
    required this.gender,
    required this.phoneController,
    required this.formKey,
    required this.imageProfile,
    super.key,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final TextEditingController fullNameController;
  final TextEditingController phoneController;
  final GlobalKey<FormState> formKey;
  final File? imageProfile;
  final String gender;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      buildWhen: (previous, current) => _buildAndListenWhen(current),
      listenWhen: (previous, current) => _buildAndListenWhen(current),
      listener: (context, state) {
        if (state.status.isRegisterSuccess) {
          successToast(context, 'عملية ناجحة', state.message);
          context.pushReplacementNamed(
            Routes.otpViewRoute,
            arguments: {
              'isForgetPassword': false,
              'email': emailController.text,
            },
          );
        }
        if (state.status.isRegisterFailure) {
          errorToast(context, 'حدث خطا', state.errorMessage);
        }
      },
      builder: (context, state) {
        return state.status.isRegisterLoading
            ? const CustomLoadingWidget()
            : CustomButton(
                text: 'انشاء حساب',
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  _registerFormValidation(context);
                },
              );
      },
    );
  }

  bool _buildAndListenWhen(AuthState state) {
    return state.status.isRegisterLoading ||
        state.status.isRegisterFailure ||
        state.status.isRegisterSuccess;
  }

  _registerFormValidation(BuildContext context) async {
    MultipartFile? imageFile;
    if (imageProfile != null) {
      imageFile = await uploadImageToApi(imageProfile ?? File(''));
    }
    final registerRequestModel = RegisterRequestModel(
      email: emailController.text,
      password: passwordController.text,
      confirmPassword: confirmPasswordController.text,
      fullName: fullNameController.text,
      phone: phoneController.text,
      role: UserRole.client.capitalized,
      gender: gender,
      imageProfile: imageFile,
      deviceType: deviceType(),
      fcmToken: CacheHelper.getString(AppConstants.fcmToken),
    );

    if (formKey.currentState!.validate() && context.mounted) {
      context.read<AuthCubit>().register(registerRequestModel);
    }
  }
}
