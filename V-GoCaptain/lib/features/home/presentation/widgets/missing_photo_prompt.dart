import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/di/di.dart';
import '../../../../core/errors/exception.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../profile/data/repo/profile_repo.dart';

/// Picks a photo from the gallery and uploads it as the captain's profile
/// picture (the one riders see). Returns true once it's saved.
Future<bool> pickAndUploadProfilePhoto(BuildContext context) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    imageQuality: 70,
    maxWidth: 800,
  );
  if (picked == null) return false;
  try {
    await getIt<ProfileRepo>().uploadProfilePhoto(picked.path);
    if (context.mounted) _toast(context, 'تم تحديث صورتك الشخصية', error: false);
    return true;
  } catch (e) {
    if (context.mounted) _toast(context, ServerFailure.fromError(e).errMessage);
    return false;
  }
}

/// Captains who signed up by phone have no profile photo, so riders see a
/// blank avatar. Ask once per app launch until one is uploaded.
Future<void> promptForMissingPhoto(BuildContext context) async {
  try {
    final profile = await getIt<ProfileRepo>().getProfile();
    final url = (profile.profilePicture ?? '').trim();
    AppConstants.kProfileImage = url;
    if (url.isNotEmpty) return;
  } catch (_) {
    return; // Don't nag if the profile couldn't be loaded.
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => const _MissingPhotoDialog(),
  );
}

class _MissingPhotoDialog extends StatefulWidget {
  const _MissingPhotoDialog();

  @override
  State<_MissingPhotoDialog> createState() => _MissingPhotoDialogState();
}

class _MissingPhotoDialogState extends State<_MissingPhotoDialog> {
  bool _saving = false;

  Future<void> _pick() async {
    setState(() => _saving = true);
    final ok = await pickAndUploadProfilePhoto(context);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.darkGrey,
      title: Text('أضف صورتك الشخصية', style: AppStyle.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 36.r,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.person, color: AppColors.black, size: 40.r),
          ),
          SizedBox(height: 12.h),
          Text(
            'حتى يتعرّف عليك العميل عند وصولك.',
            style: AppStyle.hint,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text('لاحقًا', style: AppStyle.hint),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _saving ? null : _pick,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.black),
                )
              : const Icon(Icons.photo_library_outlined,
                  color: AppColors.black),
          label: Text('اختيار صورة',
              style: AppStyle.body.copyWith(color: AppColors.black)),
        ),
      ],
    );
  }
}

void _toast(BuildContext context, String msg, {bool error = true}) {
  toastification.show(
    context: context,
    type: error ? ToastificationType.error : ToastificationType.success,
    style: ToastificationStyle.fillColored,
    title: Text(msg, style: AppStyle.body),
    autoCloseDuration: const Duration(seconds: 3),
    alignment: Alignment.bottomCenter,
  );
}
