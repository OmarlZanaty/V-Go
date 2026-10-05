import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/payment_method_badge.dart';
import '../../../../core/utils/widgets/custom_payment_web_view.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../data/models/finance_models.dart';
import '../cubit/finance_cubit.dart';

class FinanceView extends StatefulWidget {
  const FinanceView({super.key});

  @override
  State<FinanceView> createState() => _FinanceViewState();
}

class _FinanceViewState extends State<FinanceView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    final cubit = context.read<FinanceCubit>();
    if (cubit.state.summaryStatus == FinanceStatus.initial) cubit.load();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 260) {
      context.read<FinanceCubit>().loadMore();
    }
  }

  Future<void> _settle() async {
    final cubit = context.read<FinanceCubit>();
    final checkout = await cubit.createSettlement();
    if (!mounted || checkout == null || checkout.checkoutUrl.isEmpty) return;
    final redirect = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CustomPaymentWebView(url: checkout.checkoutUrl),
      ),
    );
    if (!mounted || redirect == null) return;
    await cubit.confirmPaymentCallback(redirect);
    if (!mounted) return;
    await cubit.pollSettlement(checkout.paymentId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'الحسابات',
          style: AppStyle.title.copyWith(color: AppColors.black),
        ),
      ),
      body: BlocConsumer<FinanceCubit, FinanceState>(
        listenWhen: (previous, current) =>
            previous.error != current.error ||
            previous.success != current.success,
        listener: (context, state) {
          if (state.error != null) {
            errorToast(context, 'حدث خطأ', state.error!);
          }
          if (state.success != null) {
            successToast(context, 'تم', state.success!);
          }
        },
        builder: (context, state) {
          if (state.summaryStatus == FinanceStatus.loading &&
              state.summary == null) {
            return const Center(
              child: SpinKitThreeBounce(color: AppColors.primary, size: 32),
            );
          }
          final summary = state.summary;
          if (summary == null) {
            return Center(
              child: Text('تعذّر تحميل الحسابات', style: AppStyle.hint),
            );
          }
          return RefreshIndicator(
            onRefresh: () => context.read<FinanceCubit>().refresh(),
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.all(16.w),
              children: [
                _BalanceCard(summary: summary, onSettle: _settle),
                if (summary.cashLimit > 0) ...[
                  SizedBox(height: 12.h),
                  _LimitCard(summary: summary),
                ],
                SizedBox(height: 12.h),
                _CommissionCard(percent: summary.companyCommissionPercent),
                SizedBox(height: 16.h),
                _RangeSelector(value: state.range),
                SizedBox(height: 12.h),
                _StatsGrid(stats: summary.statsFor(state.range)),
                SizedBox(height: 16.h),
                _PayoutCard(summary: summary),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Text('المعاملات', style: AppStyle.title),
                    const Spacer(),
                    if (state.ledgerStatus == FinanceStatus.loadingMore)
                      SizedBox(
                        width: 18.r,
                        height: 18.r,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 12.h),
                if (state.ledger.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 34.h),
                    child: Center(
                      child: Text('لسه مفيش معاملات', style: AppStyle.hint),
                    ),
                  )
                else
                  ...state.ledger.map((entry) => _LedgerTile(entry: entry)),
                SizedBox(height: 24.h),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary, required this.onSettle});

  final FinanceSummary summary;
  final VoidCallback onSettle;

  @override
  Widget build(BuildContext context) {
    final balance = summary.balance;
    final amount = balance.abs();
    final color = balance < 0
        ? AppColors.primaryOrange
        : balance > 0
        ? AppColors.success
        : AppColors.primary;
    final title = balance < 0
        ? 'عليك للشركة ${_money(amount)}'
        : balance > 0
        ? 'ليك عند الشركة ${_money(amount)}'
        : 'حسابك متصفّي';
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: color,
                size: 26.r,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  title,
                  style: AppStyle.heading.copyWith(color: color),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'رحلات الكاش بتحصل أجرتها وبتبقى عليك عمولة الشركة، والرحلات الإلكتروني الشركة بتحصلها وبيبقى ليك صافيك. الاتنين بيتخصموا من بعض تلقائي.',
            style: AppStyle.hint,
          ),
          if (balance < 0) ...[
            SizedBox(height: 14.h),
            SizedBox(
              height: 48.h,
              child: ElevatedButton.icon(
                onPressed: onSettle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: summary.isLocked || summary.isNearLimit
                      ? color
                      : AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                icon: const Icon(
                  Icons.payments_outlined,
                  color: AppColors.black,
                ),
                label: Text('سدّد المستحقات', style: AppStyle.button),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LimitCard extends StatelessWidget {
  const _LimitCard({required this.summary});

  final FinanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final color = summary.isLocked
        ? AppColors.danger
        : summary.isNearLimit
        ? AppColors.primaryOrange
        : AppColors.success;
    final percent = (summary.limitUsedPercent / 100).clamp(0.0, 1.0);
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('حد الكاش', style: AppStyle.body),
              const Spacer(),
              Text(
                'الحد المسموح ${_money(summary.cashLimit)}',
                style: AppStyle.hint,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 10.h,
              backgroundColor: AppColors.lightWhite,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommissionCard extends StatelessWidget {
  const _CommissionCard({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Icon(Icons.percent, color: AppColors.primary, size: 22.r),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'عمولة الشركة ${percent.toStringAsFixed(percent.truncateToDouble() == percent ? 0 : 1)}% من كل رحلة',
              style: AppStyle.body,
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.value});

  final FinanceRange value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: FinanceRange.values.map((range) {
          final selected = range == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => context.read<FinanceCubit>().selectRange(range),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  range.label,
                  textAlign: TextAlign.center,
                  style: AppStyle.body.copyWith(
                    color: selected ? AppColors.black : AppColors.grey,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final FinancePeriodStats stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('عدد الرحلات', '${stats.trips}', Icons.route),
      ('إجمالي الرحلات', _money(stats.grossFare), Icons.receipt_long),
      ('عمولة الشركة', _money(stats.companyCommission), Icons.percent),
      ('صافي ليك', _money(stats.driverNet), Icons.savings_outlined),
      ('كاش حصّلته', _money(stats.cashCollected), Icons.payments_outlined),
      ('إلكتروني', _money(stats.onlineCollected), Icons.credit_card),
    ];
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.25,
        crossAxisSpacing: 10.w,
        mainAxisSpacing: 10.h,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: EdgeInsets.all(12.w),
          decoration: _cardDecoration(radius: 14),
          child: Row(
            children: [
              Icon(item.$3, color: AppColors.primary, size: 22.r),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.$2,
                      style: AppStyle.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      item.$1,
                      style: AppStyle.hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PayoutCard extends StatelessWidget {
  const _PayoutCard({required this.summary});

  final FinanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final hasAccount = (summary.payoutAccount ?? '').trim().isNotEmpty;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('حساب الاستلام', style: AppStyle.title),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showPayoutSheet(context, summary),
                icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                label: Text(
                  'تعديل',
                  style: AppStyle.body.copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          if (!hasAccount)
            Text('لم تحدد حساب استلام', style: AppStyle.hint)
          else ...[
            Text(
              _payoutMethodLabel(summary.payoutMethod),
              style: AppStyle.body,
            ),
            SizedBox(height: 4.h),
            Text(summary.payoutAccount ?? '', style: AppStyle.hint),
            if ((summary.payoutAccountName ?? '').isNotEmpty)
              Text(summary.payoutAccountName!, style: AppStyle.hint),
          ],
        ],
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.entry});

  final FinanceLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final positive = entry.amount >= 0;
    final color = positive ? AppColors.success : AppColors.primaryOrange;
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: _cardDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_typeLabel(entry.type), style: AppStyle.body),
              ),
              Text(
                '${positive ? '+' : ''}${_money(entry.amount)}',
                style: AppStyle.body.copyWith(color: color),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(_dateTime(entry.createdAt), style: AppStyle.hint),
          if (entry.isTripEntry &&
              entry.tripFare != null &&
              entry.commissionAmount != null &&
              entry.driverNet != null) ...[
            SizedBox(height: 8.h),
            Text(
              'الأجرة ${_money(entry.tripFare!)} − عمولة ${_money(entry.commissionAmount!)} = صافي ${_money(entry.driverNet!)}',
              style: AppStyle.hint,
            ),
            SizedBox(height: 8.h),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: AppColors.lightWhite,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  paymentMethodLabel(entry.tripPaymentMethod),
                  style: AppStyle.hint.copyWith(color: AppColors.primary),
                ),
              ),
            ),
          ],
          if (entry.isPayout && (entry.reference ?? '').isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text('المرجع: ${entry.reference}', style: AppStyle.hint),
          ],
        ],
      ),
    );
  }
}

void _showPayoutSheet(BuildContext context, FinanceSummary summary) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.black,
    builder: (_) => BlocProvider.value(
      value: context.read<FinanceCubit>(),
      child: _PayoutSheet(summary: summary),
    ),
  );
}

class _PayoutSheet extends StatefulWidget {
  const _PayoutSheet({required this.summary});

  final FinanceSummary summary;

  @override
  State<_PayoutSheet> createState() => _PayoutSheetState();
}

class _PayoutSheetState extends State<_PayoutSheet> {
  late String _method;
  late final TextEditingController _account;
  late final TextEditingController _name;
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    _method = widget.summary.payoutMethod == 'MobileWallet'
        ? 'MobileWallet'
        : 'InstaPay';
    _account = TextEditingController(text: widget.summary.payoutAccount);
    _name = TextEditingController(text: widget.summary.payoutAccountName);
  }

  @override
  void dispose() {
    _account.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_account.text.trim().isEmpty ||
        _name.text.trim().isEmpty ||
        _password.text.isEmpty) {
      errorToast(context, 'راجع البيانات', 'كل البيانات مطلوبة');
      return;
    }
    if (_method == 'MobileWallet' &&
        !RegExp(r'^\d{11}$').hasMatch(_account.text.trim())) {
      errorToast(context, 'راجع الرقم', 'المحفظة لازم تكون رقم موبايل 11 رقم');
      return;
    }
    final cubit = context.read<FinanceCubit>();
    await cubit.updatePayoutAccount(
      method: _method,
      account: _account.text.trim(),
      accountName: _name.text.trim(),
      password: _password.text,
    );
    if (mounted && cubit.state.error == null) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: 18.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18.h,
      ),
      child: BlocBuilder<FinanceCubit, FinanceState>(
        builder: (context, state) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('تعديل حساب الاستلام', style: AppStyle.title),
                SizedBox(height: 14.h),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'InstaPay', label: Text('انستاباي')),
                    ButtonSegment(
                      value: 'MobileWallet',
                      label: Text('محفظة موبايل'),
                    ),
                  ],
                  selected: {_method},
                  onSelectionChanged: (value) =>
                      setState(() => _method = value.first),
                ),
                SizedBox(height: 12.h),
                _field(
                  _account,
                  _method == 'InstaPay'
                      ? 'رقم موبايل أو name@instapay'
                      : 'رقم موبايل 11 رقم',
                  Icons.account_balance_outlined,
                  keyboard: TextInputType.text,
                ),
                SizedBox(height: 10.h),
                _field(_name, 'اسم صاحب الحساب', Icons.person_outline),
                SizedBox(height: 10.h),
                _field(
                  _password,
                  'كلمة المرور الحالية',
                  Icons.lock_outline,
                  obscure: true,
                ),
                SizedBox(height: 16.h),
                SizedBox(
                  height: 50.h,
                  child: ElevatedButton(
                    onPressed: state.isSavingPayout ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: state.isSavingPayout
                        ? const SpinKitThreeBounce(
                            color: AppColors.black,
                            size: 20,
                          )
                        : Text('حفظ', style: AppStyle.button),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType? keyboard,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      style: AppStyle.body,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppStyle.hint,
        prefixIcon: Icon(icon, color: AppColors.grey),
        filled: true,
        fillColor: AppColors.darkGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration({double radius = 18}) {
  return BoxDecoration(
    color: AppColors.darkGrey,
    borderRadius: BorderRadius.circular(radius.r),
  );
}

String _money(double value) => '${value.toStringAsFixed(0)} ج.م';

String _payoutMethodLabel(String? method) {
  return switch (method) {
    'InstaPay' => 'انستاباي',
    'MobileWallet' => 'محفظة موبايل',
    _ => 'غير محدد',
  };
}

String _typeLabel(String type) {
  return switch (type) {
    'TripCashCommission' => 'عمولة رحلة كاش',
    'TripCardEarning' => 'صافي رحلة إلكتروني',
    'TripCorrection' => 'تعديل رحلة',
    'Settlement' => 'سداد مستحقات',
    'Payout' => 'تحويل ليك',
    'Adjustment' => 'تسوية إدارية',
    _ => type,
  };
}

String _dateTime(DateTime? date) {
  if (date == null) return '';
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}/${two(date.month)}/${two(date.day)}  ${two(date.hour)}:${two(date.minute)}';
}
