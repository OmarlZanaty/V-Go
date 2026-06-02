import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/upload_image_to_api.dart';
import '../../../../core/utils/logic/user_cubit/user_cubit.dart';
import '../../../../core/utils/logic/user_cubit/user_state_extension.dart';
import '../../../../core/utils/model/update_user_request_model.dart';
import '../../../../core/utils/widgets/custom_button.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';

class UpdateUserButton extends StatelessWidget {
  const UpdateUserButton({
    required this.name,
    required this.phone,
    required this.userId,
    required this.formKey,
    this.nationalId,
    this.license,
    this.scooterLicense,
    super.key,
    this.image,
    this.gender,
    this.scooterType,
  });
  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController? license;
  final TextEditingController? scooterLicense;
  final TextEditingController? nationalId;
  final GlobalKey<FormState> formKey;
  final File? image;
  final String? gender;
  final int? scooterType;
  final String userId;
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UserCubit, UserState>(
      buildWhen: (previous, current) => _buildAndListenWhen(current),
      listenWhen: (previous, current) => _buildAndListenWhen(current),
      listener: (context, state) {
        if (state.status.isUpdateUserSuccess) {
          successToast(context, 'عملية ناجحة', state.successMessage);
          context.pop(result: true);
        } else if (state.status.isUpdateUserFailure) {
          errorToast(context, 'حدث خطا', state.errorMessage);
        }
      },
      builder: (context, state) {
        return state.status.isUpdateUserLoading
            ? const CustomLoadingWidget()
            : CustomButton(
                onPressed: () async {
                  FocusManager.instance.primaryFocus?.unfocus();
                  MultipartFile? imageFile;
                  if (image != null) {
                    imageFile = await uploadImageToApi(image!);
                  }
                  if (formKey.currentState!.validate() && context.mounted) {
                    context.read<UserCubit>().updateUser(
                      userId,
                      UpdateUserRequestModel(
                        name: name.text,
                        phoneNumber: phone.text,
                        profilePicture: imageFile,
                        nationalId: nationalId?.text,
                        license: license?.text,
                        scooterLicense: scooterLicense?.text,
                        gender: gender,
                        scooterType: scooterType,
                      ),
                    );
                  }
                },
                text: 'حفظ التغييرات',
              );
      },
    );
  }

  bool _buildAndListenWhen(UserState state) {
    return state.status.isUpdateUserFailure ||
        state.status.isUpdateUserLoading ||
        state.status.isUpdateUserSuccess;
  }
}
