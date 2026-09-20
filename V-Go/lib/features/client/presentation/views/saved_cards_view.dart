import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/di.dart';
import '../../../../core/helpers/checkout_link.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/logic/saved_cards_cubit/saved_cards_cubit.dart';
import '../../../../core/utils/repo/payment_repo/payment_repo.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';

/// Profile → "بطاقاتي": lists the rider's saved Visa cards and lets them remove
/// one. Cards are saved automatically the first time the rider pays by Visa.
class SavedCardsView extends StatelessWidget {
  const SavedCardsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SavedCardsCubit(getIt<PaymentRepo>())..load(),
      child: Scaffold(
        appBar: customAppBar(title: 'بطاقاتي'),
        body: BlocConsumer<SavedCardsCubit, SavedCardsState>(
          listener: (context, state) {
            if (state.status == SavedCardsStatus.error) {
              errorToast(context, 'حدث خطأ', state.errorMessage);
            }
          },
          builder: (context, state) {
            final cubit = context.read<SavedCardsCubit>();
            if (state.status == SavedCardsStatus.loading) {
              return const Center(child: CustomLoadingWidget());
            }
            return RefreshIndicator(
              onRefresh: cubit.load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary, width: 1),
                    ),
                    child: Text(
                      'تُحفظ بطاقتك تلقائياً عند الدفع بالفيزا لأول مرة، ويمكنك '
                      'استخدامها في الرحلات التالية.',
                      style: AppStyle.styleMedium14.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  verticalSpace(12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _addCard(context, cubit),
                      icon: const Icon(Icons.add),
                      label: Text(
                        'إضافة بطاقة',
                        style: AppStyle.styleMedium14
                            .copyWith(color: AppColors.black),
                      ),
                    ),
                  ),
                  verticalSpace(16),
                  if (state.cards.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Column(
                        children: [
                          const Icon(Icons.credit_card_off_outlined,
                              size: 48, color: AppColors.grey),
                          verticalSpace(8),
                          Text(
                            'لا توجد بطاقات محفوظة',
                            style: AppStyle.styleMedium14
                                .copyWith(color: AppColors.grey),
                          ),
                        ],
                      ),
                    )
                  else
                    ...state.cards.map((card) => Card(
                          color: AppColors.darkGrey,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.credit_card,
                                color: AppColors.primary),
                            title: Text(
                              card.maskedPan.isEmpty
                                  ? 'بطاقة فيزا'
                                  : card.maskedPan,
                              style: AppStyle.styleMedium14
                                  .copyWith(color: AppColors.white),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () => _confirmDelete(context, cubit, card.id),
                            ),
                          ),
                        )),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _addCard(BuildContext context, SavedCardsCubit cubit) async {
    final res = await cubit.requestAddCard();
    if (res == null || !context.mounted) return;
    final link = getCheckoutLink(
      clientSecret: res.clientSecret,
      publicKey: res.publicKey,
    );
    await Navigator.of(context)
        .pushNamed(Routes.customPaymentWebViewRoute, arguments: link);
    if (context.mounted) cubit.load();
  }

  void _confirmDelete(BuildContext context, SavedCardsCubit cubit, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkGrey,
        title: Text('حذف البطاقة',
            style: AppStyle.styleMedium16.copyWith(color: AppColors.white)),
        content: Text('هل تريد حذف هذه البطاقة؟',
            style: AppStyle.styleMedium14.copyWith(color: AppColors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              cubit.delete(id);
            },
            child: const Text('حذف',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
