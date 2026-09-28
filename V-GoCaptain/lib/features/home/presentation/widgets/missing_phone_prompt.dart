import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/di/di.dart';
import '../../../../core/errors/exception.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../profile/data/repo/profile_repo.dart';

/// Captains created via Google before the phone was required have no number,
/// so riders can't call them. Ask once per app launch until one is saved.
Future<void> promptForMissingPhone(BuildContext context) async {
  final repo = getIt<ProfileRepo>();
  try {
    final profile = await repo.getProfile();
    if ((profile.phone ?? '').trim().isNotEmpty) return;
  } catch (_) {
    return; // Don't nag if the profile couldn't be loaded.
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _MissingPhoneDialog(repo: repo),
  );
}

class _MissingPhoneDialog extends StatefulWidget {
  const _MissingPhoneDialog({required this.repo});
  final ProfileRepo repo;

  @override
  State<_MissingPhoneDialog> createState() => _MissingPhoneDialogState();
}

class _MissingPhoneDialogState extends State<_MissingPhoneDialog> {
  final _phone = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final phone = _phone.text.trim();
    if (phone.replaceAll(RegExp(r'\D'), '').length < 10) {
      setState(() => _error = 'يرجى إدخال رقم هاتف صحيح.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repo.setPhone(phone);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = ServerFailure.fromError(e).errMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.darkGrey,
      title: Text('أضف رقم هاتفك', style: AppStyle.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'حتى يتمكن العميل من الاتصال بك أثناء الرحلة.',
            style: AppStyle.hint,
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            style: AppStyle.body,
            decoration: InputDecoration(
              hintText: '01xxxxxxxxx',
              hintStyle: AppStyle.hint,
              errorText: _error,
              prefixIcon: const Icon(Icons.phone, color: AppColors.grey),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text('لاحقًا', style: AppStyle.hint),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.black),
                )
              : Text('حفظ',
                  style: AppStyle.body.copyWith(color: AppColors.black)),
        ),
      ],
    );
  }
}
