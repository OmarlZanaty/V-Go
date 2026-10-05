import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exception.dart';
import '../../../../core/services/realtime_service.dart';
import '../../data/models/finance_models.dart';
import '../../data/repo/finance_repo.dart';

part 'finance_state.dart';

class FinanceCubit extends Cubit<FinanceState> {
  FinanceCubit(this._repo, this._realtime) : super(const FinanceState()) {
    _financeSub = _realtime.financeUpdatedStream.listen((_) => refresh());
  }

  final FinanceRepo _repo;
  final RealtimeService _realtime;
  StreamSubscription<double>? _financeSub;

  Future<void> load() async {
    if (state.summaryStatus == FinanceStatus.loading) return;
    emit(
      state.copyWith(
        summaryStatus: FinanceStatus.loading,
        ledgerStatus: FinanceStatus.loading,
        clearError: true,
        clearSuccess: true,
      ),
    );
    try {
      final summary = await _repo.getSummary();
      final page = await _repo.getLedger(pageNumber: 1);
      emit(
        state.copyWith(
          summaryStatus: FinanceStatus.loaded,
          ledgerStatus: FinanceStatus.loaded,
          summary: summary,
          ledger: page.items,
          pageNumber: page.pageNumber,
          hasNextPage: page.hasNextPage,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          summaryStatus: FinanceStatus.error,
          ledgerStatus: FinanceStatus.error,
          error: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> refresh() async {
    emit(state.copyWith(isRefreshing: true, clearError: true));
    try {
      final summary = await _repo.getSummary();
      final page = await _repo.getLedger(pageNumber: 1);
      emit(
        state.copyWith(
          summaryStatus: FinanceStatus.loaded,
          ledgerStatus: FinanceStatus.loaded,
          summary: summary,
          ledger: page.items,
          pageNumber: page.pageNumber,
          hasNextPage: page.hasNextPage,
          isRefreshing: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isRefreshing: false,
          error: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasNextPage || state.ledgerStatus == FinanceStatus.loadingMore) {
      return;
    }
    emit(state.copyWith(ledgerStatus: FinanceStatus.loadingMore));
    try {
      final page = await _repo.getLedger(pageNumber: state.pageNumber + 1);
      emit(
        state.copyWith(
          ledgerStatus: FinanceStatus.loaded,
          ledger: [...state.ledger, ...page.items],
          pageNumber: page.pageNumber,
          hasNextPage: page.hasNextPage,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          ledgerStatus: FinanceStatus.loaded,
          error: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  void selectRange(FinanceRange range) {
    emit(state.copyWith(range: range));
  }

  Future<void> updatePayoutAccount({
    required String method,
    required String account,
    required String accountName,
    required String password,
  }) async {
    emit(state.copyWith(isSavingPayout: true, clearError: true));
    try {
      await _repo.updatePayoutAccount(
        method: method,
        account: account,
        accountName: accountName,
        password: password,
      );
      final summary = await _repo.getSummary();
      emit(
        state.copyWith(
          isSavingPayout: false,
          summary: summary,
          success: 'تم حفظ حساب الاستلام',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isSavingPayout: false,
          error: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<FinanceSettlementCheckout?> createSettlement() async {
    emit(
      state.copyWith(isSettling: true, clearError: true, clearSuccess: true),
    );
    try {
      final checkout = await _repo.createSettlement();
      emit(state.copyWith(isSettling: false));
      return checkout;
    } catch (e) {
      emit(
        state.copyWith(
          isSettling: false,
          error: ServerFailure.fromError(e).errMessage,
        ),
      );
      return null;
    }
  }

  Future<void> confirmPaymentCallback(String redirectUrl) async {
    emit(state.copyWith(isSettling: true, clearError: true));
    try {
      await _repo.confirmPaymentCallback(redirectUrl);
      emit(state.copyWith(isSettling: false));
    } catch (e) {
      emit(
        state.copyWith(
          isSettling: false,
          error: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<FinanceSettlementStatus?> pollSettlement(String paymentId) async {
    emit(state.copyWith(isSettling: true, clearError: true));
    FinanceSettlementStatus? last;
    try {
      for (var i = 0; i < 15; i++) {
        last = await _repo.getSettlementStatus(paymentId);
        if (last.credited || last.isFailed) break;
        await Future.delayed(const Duration(seconds: 2));
      }
      await refresh();
      final credited = last?.credited == true;
      emit(
        state.copyWith(
          isSettling: false,
          success: credited
              ? (last!.canGoOnline
                    ? 'تم السداد ✅ — تقدر تشتغل دلوقتي'
                    : 'تم السداد بنجاح')
              : null,
          error: credited
              ? null
              : 'لسه عملية السداد ما اتأكدتش، راجعها بعد شوية.',
        ),
      );
      return last;
    } catch (e) {
      emit(
        state.copyWith(
          isSettling: false,
          error: ServerFailure.fromError(e).errMessage,
        ),
      );
      return last;
    }
  }

  @override
  Future<void> close() async {
    await _financeSub?.cancel();
    return super.close();
  }
}
