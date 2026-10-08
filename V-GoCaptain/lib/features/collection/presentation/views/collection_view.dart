import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../data/models/collection_models.dart';
import '../cubit/collection_cubit.dart';

/// Daily collection: the captain transfers his dues to a company wallet and
/// files the transfer; it's confirmed automatically when the wallet's receipt
/// SMS reaches the company, and any collection lock lifts by itself.
class CollectionView extends StatefulWidget {
  const CollectionView({super.key});

  @override
  State<CollectionView> createState() => _CollectionViewState();
}

class _CollectionViewState extends State<CollectionView> {
  final _sender = TextEditingController();
  final _account = TextEditingController(); // InstaPay address
  final _name = TextEditingController(); // name shown by InstaPay
  int? _walletId;
  bool _prefilled = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // Keeps the countdown fresh.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _sender.dispose();
    _account.dispose();
    _name.dispose();
    super.dispose();
  }

  void _prefill(MyCollection data) {
    if (_prefilled) return;
    _prefilled = true;
    _sender.text = data.lastSenderPhone ?? '';
    _account.text = data.lastSenderAccount ?? '';
    _name.text = data.lastSenderName ?? '';
    _walletId = data.wallets.isNotEmpty ? data.wallets.first.id : null;
  }

  CollectionWallet? _selected(MyCollection data) =>
      data.wallets.where((w) => w.id == _walletId).firstOrNull;

  Future<void> _submit(MyCollection data) async {
    final wallet = _selected(data);
    final sender = _toLatinDigits(_sender.text).replaceAll(RegExp(r'[\s-]'), '');
    final account = _account.text.trim().toLowerCase().replaceAll(' ', '');
    final name = _name.text.trim();
    // The captain doesn't type the amount: he transfers exactly what he owes,
    // rounded down to whole pounds (piasters are dropped so the receipt SMS
    // matches on a clean number instead of stalling in review).
    final amount = data.owedToCompany.floorToDouble();
    final validPhone = RegExp(r'^01[0125]\d{8}$').hasMatch(sender);
    if (wallet == null) {
      errorToast(context, 'اختار الحساب', 'اختار رقم أو حساب الشركة اللي حوّلت عليه');
      return;
    }
    if (wallet.isInstaPay) {
      if (account.isNotEmpty &&
          !RegExp(r'^[a-z0-9][a-z0-9._\-]{1,60}@instapay$').hasMatch(account)) {
        errorToast(context, 'راجع العنوان', 'عنوان انستاباي بيبقى بالشكل name@instapay');
        return;
      }
      if (sender.isNotEmpty && !validPhone) {
        errorToast(context, 'راجع الرقم', 'رقم الموبايل لازم يكون 11 رقم');
        return;
      }
      if (account.isEmpty && sender.isEmpty) {
        errorToast(context, 'ناقص بيانات', 'اكتب عنوان انستاباي أو رقم الموبايل اللي حوّلت منه');
        return;
      }
      if (name.length < 3) {
        errorToast(context, 'ناقص بيانات', 'اكتب اسمك زي ما بيظهر في انستاباي');
        return;
      }
    } else if (!validPhone) {
      errorToast(context, 'راجع الرقم', 'اكتب رقم المحفظة اللي حوّلت منها (11 رقم)');
      return;
    }
    if (amount < 1) {
      errorToast(context, 'مفيش مبلغ', 'مفيش مستحقات مطلوبة للتحويل دلوقتي');
      return;
    }
    FocusScope.of(context).unfocus();
    await context.read<CollectionCubit>().submit(
      walletId: wallet.id,
      senderPhone: sender.isEmpty ? null : sender,
      senderAccount: wallet.isInstaPay && account.isNotEmpty ? account : null,
      senderName: name.isEmpty ? null : name,
      amount: amount,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'تحويل المستحقات',
          style: AppStyle.title.copyWith(color: AppColors.black),
        ),
      ),
      body: BlocConsumer<CollectionCubit, CollectionState>(
        listenWhen: (p, c) => p.error != c.error || p.success != c.success,
        listener: (context, state) {
          if (state.error != null) errorToast(context, 'حدث خطأ', state.error!);
          if (state.success != null) successToast(context, 'تم', state.success!);
        },
        builder: (context, state) {
          final data = state.data;
          if (data == null) {
            return Center(
              child: state.loading
                  ? const SpinKitThreeBounce(color: AppColors.primary, size: 32)
                  : TextButton(
                      onPressed: () => context.read<CollectionCubit>().load(),
                      child: Text('إعادة المحاولة', style: AppStyle.body),
                    ),
            );
          }
          _prefill(data);
          final pending = data.pending;
          final transferAmount = data.owedToCompany.floorToDouble();
          final showForm = data.enabled &&
              transferAmount >= 1 &&
              pending?.isPending != true;
          return RefreshIndicator(
            onRefresh: () => context.read<CollectionCubit>().refresh(),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16.w,
                16.h,
                16.w,
                24.h + MediaQuery.of(context).viewInsets.bottom,
              ),
              children: [
                _DueCard(data: data),
                if (pending != null) ...[
                  SizedBox(height: 12.h),
                  _PendingCard(
                    request: pending,
                    busy: state.submitting,
                    onCancel: () =>
                        context.read<CollectionCubit>().cancel(pending.id),
                  ),
                ],
                if (!data.enabled) ...[
                  SizedBox(height: 12.h),
                  _Note(
                    icon: Icons.info_outline,
                    text: 'التحصيل عن طريق المحفظة مش مفعّل حالياً.',
                  ),
                ],
                if (showForm) ...[
                  SizedBox(height: 18.h),
                  _StepTitle(number: 1, text: 'حوّل المبلغ على محفظة أو حساب انستاباي للشركة'),
                  SizedBox(height: 10.h),
                  ...data.wallets.map(
                    (w) => _WalletTile(
                      wallet: w,
                      selected: w.id == _walletId,
                      onTap: () => setState(() => _walletId = w.id),
                    ),
                  ),
                  if (data.wallets.isEmpty)
                    _Note(
                      icon: Icons.error_outline,
                      text: 'مفيش أرقام تحويل متاحة دلوقتي، كلّم الدعم.',
                    ),
                  SizedBox(height: 18.h),
                  _StepTitle(number: 2, text: 'اكتب بيانات التحويل اللي عملته'),
                  SizedBox(height: 10.h),
                  if (_selected(data)?.isInstaPay == true) ...[
                    _field(
                      _account,
                      'عنوان انستاباي اللي حوّلت منه (name@instapay)',
                      Icons.alternate_email,
                      keyboard: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 10.h),
                    _field(
                      _sender,
                      'أو رقم الموبايل المربوط بانستاباي (اختياري)',
                      Icons.phone_android,
                    ),
                    SizedBox(height: 10.h),
                    _field(
                      _name,
                      'اسمك زي ما بيظهر في انستاباي',
                      Icons.person_outline,
                      keyboard: TextInputType.name,
                    ),
                  ] else
                    _field(
                      _sender,
                      'رقم المحفظة اللي حوّلت منها',
                      Icons.phone_android,
                    ),
                  SizedBox(height: 10.h),
                  _AmountBox(amount: transferAmount),
                  SizedBox(height: 8.h),
                  Text(
                    _selected(data)?.isInstaPay == true
                        ? 'حوّل المبلغ ده بالظبط (${_money(transferAmount)})، والعنوان والاسم زي اللي في انستاباي، علشان التأكيد يتم تلقائي.'
                        : 'حوّل المبلغ ده بالظبط (${_money(transferAmount)}) من نفس الرقم، علشان التأكيد يتم تلقائي.',
                    style: AppStyle.hint,
                  ),
                  SizedBox(height: 16.h),
                  SizedBox(
                    height: 52.h,
                    child: ElevatedButton(
                      onPressed: state.submitting || data.wallets.isEmpty
                          ? null
                          : () => _submit(data),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: state.submitting
                          ? const SpinKitThreeBounce(color: AppColors.black, size: 20)
                          : Text('حوّلت، أكّد التحويل', style: AppStyle.button),
                    ),
                  ),
                ],
                if (data.recent.any((r) => r.id != pending?.id)) ...[
                  SizedBox(height: 24.h),
                  Text('التحويلات السابقة', style: AppStyle.title),
                  SizedBox(height: 10.h),
                  ...data.recent
                      .where((r) => r.id != pending?.id)
                      .map((r) => _HistoryTile(request: r)),
                ],
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
    bool decimal = false,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard ??
          (decimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.phone),
      style: AppStyle.body,
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: AppStyle.hint,
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

class _DueCard extends StatelessWidget {
  const _DueCard({required this.data});

  final MyCollection data;

  @override
  Widget build(BuildContext context) {
    final color = data.isLocked
        ? AppColors.danger
        : data.mustPay
        ? AppColors.primaryOrange
        : AppColors.success;
    final deadline = MyCollection.hourLabel(data.deadlineHour);
    final String status;
    if (data.isLocked) {
      status =
          'استقبال الرحلات متوقف لأن ميعاد التحصيل عدّى. أول ما تحويلك يتأكد الحساب هيتفتح لوحده.';
    } else if (data.mustPay && data.inWindow) {
      status = 'حوّل قبل الساعة $deadline${_remaining(data)} علشان استقبال الرحلات ما يتوقفش.';
    } else if (data.mustPay) {
      status =
          'التحصيل كل يوم من الساعة ${MyCollection.hourLabel(data.noticeHour)} لحد $deadline. تقدر تحوّل من دلوقتي.';
    } else if (data.owedToCompany > 0) {
      status =
          'المبلغ أقل من ${_money(data.tolerance)}، مش مطلوب تحوّله النهارده.';
    } else {
      status = 'مفيش عليك مستحقات للشركة.';
    }
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                data.isLocked ? Icons.lock_outline : Icons.account_balance_wallet_outlined,
                color: color,
                size: 26.r,
              ),
              SizedBox(width: 10.w),
              Text('المطلوب منك', style: AppStyle.body),
              const Spacer(),
              Text(
                _money(data.owedToCompany),
                style: AppStyle.heading.copyWith(color: color),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(status, style: AppStyle.hint.copyWith(color: AppColors.white)),
        ],
      ),
    );
  }

  static String _remaining(MyCollection data) {
    final deadline = data.deadlineAt;
    if (deadline == null) return '';
    // Server clock (Egypt time) is the reference; correct for the phone's drift.
    final drift = data.serverTime == null
        ? Duration.zero
        : data.serverTime!.difference(DateTime.now());
    final left = deadline.difference(DateTime.now().add(drift));
    if (left.isNegative) return '';
    final h = left.inHours, m = left.inMinutes % 60;
    final text = h > 0 ? '$h ساعة${m > 0 ? ' و $m دقيقة' : ''}' : '$m دقيقة';
    return ' (فاضل $text)';
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 13.r,
          backgroundColor: AppColors.primary,
          child: Text(
            '$number',
            style: AppStyle.body.copyWith(color: AppColors.black),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(child: Text(text, style: AppStyle.title)),
      ],
    );
  }
}

class _WalletTile extends StatelessWidget {
  const _WalletTile({
    required this.wallet,
    required this.selected,
    required this.onTap,
  });

  final CollectionWallet wallet;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = wallet.isVodafone
        ? const Color(0xFFE60000)
        : wallet.isInstaPay
        ? const Color(0xFF9B59D0)
        : const Color(0xFF6CBE45);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.darkGrey,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.primary : AppColors.grey,
            ),
            SizedBox(width: 10.w),
            Container(
              width: 6.w,
              height: 38.h,
              decoration: BoxDecoration(
                color: brand,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wallet.providerLabel,
                    style: AppStyle.hint.copyWith(color: brand),
                  ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      wallet.phoneNumber,
                      style: AppStyle.title.copyWith(
                        letterSpacing: wallet.isInstaPay ? 0 : 1.2,
                      ),
                    ),
                  ),
                  Text(
                    [wallet.holderName, wallet.bankName]
                        .whereType<String>()
                        .where((s) => s.isNotEmpty)
                        .join(' — '),
                    style: AppStyle.hint,
                  ),
                  if (!wallet.isOnline)
                    Text(
                      'التأكيد على الرقم ده ممكن يتأخر شوية',
                      style: AppStyle.hint.copyWith(color: AppColors.primaryOrange),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: wallet.isInstaPay ? 'نسخ العنوان' : 'نسخ الرقم',
              icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: wallet.phoneNumber));
                if (context.mounted) {
                  successToast(
                    context,
                    'اتنسخ',
                    wallet.isInstaPay
                        ? 'عنوان انستاباي اتنسخ'
                        : 'رقم ${wallet.providerLabel} اتنسخ',
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-only amount the captain must transfer (he can't change it).
class _AmountBox extends StatelessWidget {
  const _AmountBox({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.payments_outlined, color: AppColors.grey),
          SizedBox(width: 10.w),
          Text('المبلغ المطلوب تحويله', style: AppStyle.body),
          const Spacer(),
          Text(
            _money(amount),
            style: AppStyle.heading.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.request,
    required this.busy,
    required this.onCancel,
  });

  final CollectionRequest request;
  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final review = request.status == 'NeedsReview';
    final color = review ? AppColors.primaryOrange : AppColors.primary;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (!review)
                SizedBox(
                  width: 18.r,
                  height: 18.r,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              else
                Icon(Icons.hourglass_top, color: color, size: 20.r),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  request.statusLabel,
                  style: AppStyle.title.copyWith(color: color),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'تحويل ${_money(request.amount)} من ${request.senderLabel}',
            style: AppStyle.body,
          ),
          SizedBox(height: 6.h),
          Text(
            review
                ? (request.note ?? 'الإدارة بتراجع التحويل وهتبلغك.')
                : 'هيتأكد تلقائي أول ما رسالة الاستلام توصل للشركة (عادةً خلال دقايق).',
            style: AppStyle.hint,
          ),
          if (request.isPending) ...[
            SizedBox(height: 6.h),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: busy ? null : onCancel,
                child: Text(
                  'كتبت حاجة غلط؟ إلغاء الطلب',
                  style: AppStyle.hint.copyWith(color: AppColors.danger),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.request});

  final CollectionRequest request;

  @override
  Widget build(BuildContext context) {
    final color = switch (request.status) {
      'Confirmed' => AppColors.success,
      'Rejected' || 'Expired' => AppColors.danger,
      'Cancelled' => AppColors.grey,
      _ => AppColors.primaryOrange,
    };
    final shown = request.receivedAmount ?? request.amount;
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(_money(shown), style: AppStyle.body)),
              Text(request.statusLabel, style: AppStyle.hint.copyWith(color: color)),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            'من ${request.senderLabel}  •  ${_dateTime(request.createdAt)}',
            style: AppStyle.hint,
          ),
          if ((request.note ?? '').isNotEmpty)
            Text(request.note!, style: AppStyle.hint),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryOrange),
          SizedBox(width: 10.w),
          Expanded(child: Text(text, style: AppStyle.body)),
        ],
      ),
    );
  }
}

String _money(double value) =>
    '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)} ج.م';

String _toLatinDigits(String input) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  final buffer = StringBuffer();
  for (final ch in input.characters) {
    final i = arabic.indexOf(ch);
    buffer.write(i >= 0 ? '$i' : (ch == '٫' ? '.' : ch));
  }
  return buffer.toString();
}

String _dateTime(DateTime? date) {
  if (date == null) return '';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}  ${two(date.hour)}:${two(date.minute)}';
}
