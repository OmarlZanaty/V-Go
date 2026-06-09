import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exception.dart';
import '../../data/repo/profile_repo.dart';

part 'support_state.dart';

class SupportCubit extends Cubit<SupportState> {
  final ProfileRepo _repo;
  SupportCubit(this._repo) : super(const SupportState());

  Future<void> submit(String message) async {
    final text = message.trim();
    if (text.isEmpty) return;
    emit(state.copyWith(status: SupportStatus.submitting, clearError: true));
    try {
      await _repo.sendSupportReport(text);
      emit(state.copyWith(status: SupportStatus.success));
    } catch (e) {
      emit(state.copyWith(
        status: SupportStatus.error,
        error: ServerFailure.fromError(e).errMessage,
      ));
    }
  }

  void reset() => emit(const SupportState());
}
