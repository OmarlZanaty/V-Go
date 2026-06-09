import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exception.dart';
import '../../data/models/driver_profile_model.dart';
import '../../data/repo/profile_repo.dart';

part 'scooter_state.dart';

class ScooterCubit extends Cubit<ScooterState> {
  final ProfileRepo _repo;
  ScooterCubit(this._repo) : super(const ScooterState());

  Future<void> load() async {
    emit(state.copyWith(status: ScooterStatus.loading, clearError: true));
    try {
      final profile = await _repo.getProfile();
      emit(state.copyWith(status: ScooterStatus.loaded, profile: profile));
    } catch (e) {
      emit(state.copyWith(
        status: ScooterStatus.error,
        error: ServerFailure.fromError(e).errMessage,
      ));
    }
  }
}
