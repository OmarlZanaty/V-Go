import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/api/api_service.dart';
import '../../../../core/api/end_points.dart';
import '../../../../core/cache/cache_helper.dart';
import '../../../../core/di/di.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/widgets/custom_button.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';

/// Non-dismissible gate for existing captains whose gender isn't confirmed.
/// Trips are matched by gender, so the captain must choose before going online.
class GenderGateView extends StatefulWidget {
  const GenderGateView({super.key, this.openVerificationOnStart = false});
  final bool openVerificationOnStart;

  @override
  State<GenderGateView> createState() => _GenderGateViewState();
}

class _GenderGateViewState extends State<GenderGateView> {
  String? _gender; // 'Male' | 'Female'
  bool _busy = false;

  Future<void> _submit() async {
    final value = _gender;
    if (value == null) {
      errorToast(context, 'تنبيه', 'اختار النوع الأول.');
      return;
    }
    setState(() => _busy = true);
    var ok = false;
    try {
      await getIt<ApiServices>().put(
        EndPoint.setGender,
        data: {'gender': value},
      );
      ok = true;
    } on DioException catch (e) {
      // 409 = already confirmed on the server: just continue.
      ok = e.response?.statusCode == 409;
      if (!ok && mounted) {
        errorToast(context, 'حدث خطأ', 'تعذر حفظ النوع، حاول مرة أخرى.');
      }
    } catch (_) {
      if (mounted) {
        errorToast(context, 'حدث خطأ', 'تعذر حفظ النوع، حاول مرة أخرى.');
      }
    }
    if (!ok) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    await CacheHelper.setData(key: AppConstants.genderConfirmed, value: true);
    await CacheHelper.setData(key: AppConstants.gender, value: value);
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.captainHomeViewRoute,
      (route) => false,
      arguments: {'openVerificationOnStart': widget.openVerificationOnStart},
    );
  }

  Widget _option(String value, String label) {
    return RadioListTile<String>(
      value: value,
      groupValue: _gender,
      title: Text(label, style: AppStyle.styleMedium16),
      activeColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
      onChanged: _busy ? null : (v) => setState(() => _gender = v),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Text(
                  'اختار النوع',
                  textAlign: TextAlign.center,
                  style: AppStyle.heading,
                ),
                const SizedBox(height: 12),
                Text(
                  'الرحلات بتتوزع حسب النوع، عشان كده لازم تحدد نوعك قبل ما تكمل.',
                  textAlign: TextAlign.center,
                  style: AppStyle.styleMedium14,
                ),
                const SizedBox(height: 24),
                _option('Male', 'ذكر'),
                _option('Female', 'أنثى'),
                const Spacer(),
                _busy
                    ? const CustomLoadingWidget()
                    : CustomButton(text: 'متابعة', onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
