import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exception.dart';
import '../../data/models/trip_model.dart';
import '../../data/repo/trip_repo.dart';

part 'trips_state.dart';

class TripsCubit extends Cubit<TripsState> {
  final TripRepo _repo;
  TripsCubit(this._repo) : super(const TripsState());

  Future<void> load() async {
    emit(state.copyWith(status: TripsStatus.loading, clearError: true));
    try {
      final trips = await _repo.getMyTrips();
      trips.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      emit(state.copyWith(status: TripsStatus.loaded, trips: trips));
    } catch (e) {
      emit(state.copyWith(
        status: TripsStatus.error,
        error: ServerFailure.fromError(e).errMessage,
      ));
    }
  }
}
