import 'package:flutter/material.dart';

import '../../../../core/cache/cache_helper.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';

const _acceptedKey = 'locationDisclosureAccepted';

/// Store-required "prominent disclosure": before the first time the captain
/// goes online (which starts location tracking that keeps running in the
/// background), explain what is collected and why. Asked once; true if the
/// captain agreed (now or before).
Future<bool> confirmLocationDisclosure(BuildContext context) async {
  if (CacheHelper.getBool(_acceptedKey)) return true;
  final agreed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.darkGrey,
      title: Text(
        'استخدام موقعك',
        style: AppStyle.title.copyWith(color: Colors.white),
      ),
      content: Text(
        'يجمع تطبيق V-Go Captain بيانات موقعك لإرسال طلبات الرحلات القريبة '
        'منك، ولعرض موقعك للعميل أثناء الرحلة، ولحساب المسافة والأجرة.\n\n'
        'يستمر جمع الموقع حتى عندما يكون التطبيق مغلقًا أو في الخلفية '
        'طوال فترة كونك "متاح"، ويتوقف فور تحويل حالتك إلى "غير متاح".',
        style: AppStyle.body.copyWith(color: Colors.white),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('لا أوافق', style: AppStyle.body),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            'موافق',
            style: AppStyle.body.copyWith(color: AppColors.primary),
          ),
        ),
      ],
    ),
  );
  if (agreed == true) {
    await CacheHelper.setData(key: _acceptedKey, value: true);
    return true;
  }
  return false;
}
