import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exception.dart';
import '../../../../core/services/realtime_service.dart';
import '../../data/models/collection_models.dart';
import '../../data/repo/collection_repo.dart';

part 'collection_state.dart';

class CollectionCubit extends Cubit<CollectionState> {
  CollectionCubit(this._repo, this._realtime) : super(const CollectionState()) {
    // A confirmed transfer posts to the ledger, which pushes DriverFinanceUpdated.
    _financeSub = _realtime.financeUpdatedStream.listen((_) => refresh());
  }

  final CollectionRepo _repo;
  final RealtimeService _realtime;
  StreamSubscription<double>? _financeSub;
  Timer? _poll;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final data = await _repo.getMine();
      if (isClosed) return;
      emit(state.copyWith(data: data, loading: false, clearError: true));
      _schedulePoll(data);
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          loading: false,
          error: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  // While a request waits for its SMS, check every 15 s (SignalR may be down).
  void _schedulePoll(MyCollection data) {
    _poll?.cancel();
    if (data.pending?.isPending == true) {
      _poll = Timer(const Duration(seconds: 15), refresh);
    }
  }

  Future<bool> submit({
    required int walletId,
    String? senderPhone,
    String? senderAccount,
    String? senderName,
    required double amount,
  }) async {
    emit(state.copyWith(submitting: true, clearError: true, clearSuccess: true));
    try {
      final (request, message) = await _repo.createRequest(
        walletId: walletId,
        senderPhone: senderPhone,
        senderAccount: senderAccount,
        senderName: senderName,
        amount: amount,
      );
      if (isClosed) return false;
      emit(
        state.copyWith(
          submitting: false,
          success: message ?? request.statusLabel,
        ),
      );
      await refresh();
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          submitting: false,
          error: ServerFailure.fromError(e).errMessage,
        ),
      );
      return false;
    }
  }

  Future<void> cancel(int id) async {
    emit(state.copyWith(submitting: true, clearError: true, clearSuccess: true));
    try {
      await _repo.cancelRequest(id);
      if (isClosed) return;
      emit(state.copyWith(submitting: false, success: 'تم إلغاء الطلب'));
      await refresh();
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          submitting: false,
          error: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _poll?.cancel();
    _financeSub?.cancel();
    return super.close();
  }
}
