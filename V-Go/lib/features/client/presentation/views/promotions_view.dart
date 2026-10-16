import 'package:flutter/material.dart';

import '../../../../core/di/di.dart';
import '../../../../core/errors/exception.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../data/model/promotion_model.dart';
import '../../data/repo/promotion_repo.dart';

/// Settings → "العروض وأكواد الخصم": the rider's running offers, and a field
/// to enter a promo code. The best offer is applied automatically when booking.
class PromotionsView extends StatefulWidget {
  const PromotionsView({super.key});

  @override
  State<PromotionsView> createState() => _PromotionsViewState();
}

class _PromotionsViewState extends State<PromotionsView> {
  final _repo = getIt<PromotionRepo>();
  final _code = TextEditingController();
  List<PromotionModel> _offers = const [];
  bool _loading = true;
  bool _redeeming = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final offers = await _repo.mine();
      if (!mounted) return;
      setState(() => _offers = offers);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ServerFailure.fromError(e).errMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _redeem() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _redeeming = true);
    try {
      final msg = await _repo.redeem(code);
      if (!mounted) return;
      _code.clear();
      successToast(context, 'تم', msg);
      await _load();
    } catch (e) {
      if (!mounted) return;
      errorToast(context, 'الكود', ServerFailure.fromError(e).errMessage);
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: 'العروض وأكواد الخصم'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _codeCard(),
            verticalSpace(20),
            Text('عروضك الحالية', style: AppStyle.styleMedium16),
            verticalSpace(4),
            Text(
              'أفضل عرض بيتطبق تلقائيًا على رحلتك الجاية، وبيظهر السعر بعد الخصم قبل ما تطلب.',
              style: AppStyle.styleRegular12.copyWith(color: AppColors.grey),
            ),
            verticalSpace(12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CustomLoadingWidget()),
              )
            else if (_error != null)
              _message(_error!, Icons.wifi_off_rounded)
            else if (_offers.isEmpty)
              _message(
                'مفيش عروض متاحة ليك دلوقتي. لو معاك كود خصم اكتبه فوق.',
                Icons.card_giftcard_rounded,
              )
            else
              ..._offers.map(_offerCard),
          ],
        ),
      ),
    );
  }

  Widget _codeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('معاك كود خصم؟', style: AppStyle.styleMedium14),
          verticalSpace(10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  textDirection: TextDirection.ltr,
                  style: AppStyle.styleMedium16,
                  onSubmitted: (_) => _redeem(),
                  decoration: InputDecoration(
                    hintText: 'VGO10',
                    hintStyle: AppStyle.styleRegular14.copyWith(color: AppColors.grey),
                    filled: true,
                    fillColor: AppColors.lightWhite,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              horizontalSpace(8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _redeeming ? null : _redeem,
                  child: _redeeming
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black),
                        )
                      : Text('تفعيل', style: AppStyle.styleMedium14.copyWith(color: AppColors.black)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _offerCard(PromotionModel p) {
    final ends = p.endsAt;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightWhite),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.card_giftcard_rounded, color: AppColors.primary),
          ),
          horizontalSpace(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.title, style: AppStyle.styleMedium16),
                verticalSpace(2),
                Text(
                  p.offerLabel,
                  style: AppStyle.styleMedium14.copyWith(color: AppColors.primary),
                ),
                if (p.description != null && p.description!.isNotEmpty) ...[
                  verticalSpace(4),
                  Text(
                    p.description!,
                    style: AppStyle.styleRegular12.copyWith(color: AppColors.grey),
                  ),
                ],
                verticalSpace(6),
                Text(
                  'باقي لك ${p.ridesLeft} من ${p.ridesPerRider} ${p.ridesPerRider == 1 ? 'رحلة' : 'رحلات'}'
                  '${ends != null ? ' · لحد ${ends.day}/${ends.month}/${ends.year}' : ''}',
                  style: AppStyle.styleRegular12.copyWith(color: AppColors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.grey),
          verticalSpace(10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppStyle.styleRegular14.copyWith(color: AppColors.grey),
          ),
        ],
      ),
    );
  }
}
