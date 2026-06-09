import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/get_route.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_button.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_text_field.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../logic/cubit/auth_cubit.dart';

/// Shown the first time a user signs in with Google when no account exists yet.
/// Collects the required profile (full name + phone). The photo is optional and
/// defaults to the Google profile photo.
class GoogleCompleteProfileView extends StatefulWidget {
  const GoogleCompleteProfileView({
    super.key,
    required this.idToken,
    required this.name,
    required this.photo,
  });

  final String idToken;
  final String name;
  final String photo;

  @override
  State<GoogleCompleteProfileView> createState() =>
      _GoogleCompleteProfileViewState();
}

class _GoogleCompleteProfileViewState extends State<GoogleCompleteProfileView> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.name);
  final _phoneController = TextEditingController();
  String _gender = 'Male';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: 'إكمال البيانات'),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.loginWithGoogleSuccess) {
            context.pushNamedAndRemoveUntil(
              getRoute(),
              predicate: (route) => false,
            );
          } else if (state.status == AuthStatus.loginWithGoogleFailure) {
            errorToast(context, 'حدث خطأ', state.errorMessage);
          }
        },
        builder: (context, state) {
          final busy = state.status == AuthStatus.loginWithGoogleLoading;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                verticalSpace(16),
                Center(
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.lightGrey,
                    backgroundImage: widget.photo.isNotEmpty
                        ? CachedNetworkImageProvider(widget.photo)
                        : null,
                    child: widget.photo.isEmpty
                        ? const Icon(Icons.person, size: 44, color: AppColors.grey)
                        : null,
                  ),
                ),
                verticalSpace(8),
                Center(
                  child: Text(
                    'الصورة اختيارية (سيتم استخدام صورة Google)',
                    style: AppStyle.styleRegular12.copyWith(color: AppColors.grey),
                  ),
                ),
                verticalSpace(20),
                CustomTextField(
                  labelText: 'الاسم بالكامل',
                  controller: _nameController,
                ),
                verticalSpace(16),
                CustomTextField(
                  labelText: 'رقم الهاتف',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                ),
                verticalSpace(16),
                Text('الجنس', style: AppStyle.styleMedium14),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        value: 'Male',
                        groupValue: _gender,
                        title: const Text('ذكر'),
                        activeColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setState(() => _gender = v!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        value: 'Female',
                        groupValue: _gender,
                        title: const Text('أنثى'),
                        activeColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setState(() => _gender = v!),
                      ),
                    ),
                  ],
                ),
                verticalSpace(24),
                busy
                    ? const CustomLoadingWidget()
                    : CustomButton(
                        text: 'إنشاء الحساب',
                        onPressed: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          final name = _nameController.text.trim();
                          if (name.length < 2) {
                            errorToast(context, 'تنبيه', 'يرجى إدخال الاسم.');
                            return;
                          }
                          final phone = _phoneController.text.trim();
                          if (phone.replaceAll(RegExp(r'[^0-9]'), '').length < 8) {
                            errorToast(context, 'تنبيه', 'يرجى إدخال رقم هاتف صحيح.');
                            return;
                          }
                          context.read<AuthCubit>().completeGoogleProfile(
                                idToken: widget.idToken,
                                fullName: name,
                                phone: phone,
                                gender: _gender,
                                profilePicture:
                                    widget.photo.isEmpty ? null : widget.photo,
                              );
                        },
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}
