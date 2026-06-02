import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/errors/exception.dart';
import '../../../../../core/utils/app_constants.dart';
import '../../../../../core/utils/model/current_trip_model.dart';
import '../../../data/model/trip_model.dart';
import '../../../data/repo/trip_repo.dart';

part 'trip_state.dart';

class TripCubit extends Cubit<TripState> {
  TripCubit(this._tripRepo) : super(const TripState());
  final TripRepo _tripRepo;

  Future<void> getAllTrips({
    String? userId,
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    emit(state.copyWith(status: TripStatus.getAllTripsLoading));
    try {
      final allTripsResponse = await _tripRepo.getAllTrips(
        userId: userId,
        pageNumber: pageNumber,
        pageSize: pageSize,
      );
      emit(
        state.copyWith(
          status: TripStatus.getAllTripsSuccess,
          trips: state.trips + allTripsResponse.trips,
          filteredTrips: state.filteredTrips + allTripsResponse.trips,
          hasNextPage: allTripsResponse.hasNextPage,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: TripStatus.getAllTripsFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  void filterTripsByStatus(String status) {
    if (status.isEmpty) {
      if (state.trips.isEmpty) {
        emit(
          state.copyWith(
            status: TripStatus.getAllTripsFailure,
            errorMessage: 'حدث خطأ في تحميل الرحلات',
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: TripStatus.getAllTripsSuccess,
          filteredTrips: state.trips,
        ),
      );
    } else {
      final filtered = state.trips
          .where((trip) => trip.status.toLowerCase() == status.toLowerCase())
          .toList();
      if (filtered.isEmpty) {
        emit(
          state.copyWith(
            status: TripStatus.getAllTripsFailure,
            errorMessage: 'لا يوجد رحلات بهذه الحالة',
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: TripStatus.getAllTripsSuccess,
          filteredTrips: filtered,
        ),
      );
    }
  }

  Future<void> getCurrentTrips() async {
    emit(state.copyWith(status: TripStatus.getAllTripsLoading));
    try {
      final currentTrips = await _tripRepo.getCurrentTrips(
        userId: AppConstants.kUserId,
      );
      emit(
        state.copyWith(
          status: TripStatus.getAllTripsSuccess,
          currentTrips: currentTrips,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: TripStatus.getAllTripsFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> changeKiloPrice({required double kiloPrice}) async {
    emit(state.copyWith(status: TripStatus.changeKiloPriceLoading));
    try {
      final response = await _tripRepo.changeTripPricePerKilometer(
        price: kiloPrice,
      );

      emit(
        state.copyWith(
          status: TripStatus.changeKiloPriceSuccess,
          successMessage: response,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: TripStatus.changeKiloPriceFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> getTripKiloPrice() async {
    emit(state.copyWith(status: TripStatus.getTripKiloPriceLoading));
    try {
      final price = await _tripRepo.getTripPricePerKilometer();
      emit(
        state.copyWith(
          status: TripStatus.getTripKiloPriceSuccess,
          tripPrice: price,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: TripStatus.getTripKiloPriceFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> changeDriverCommission({required double percentage}) async {
    emit(state.copyWith(status: TripStatus.changeDriverCommissionLoading));
    try {
      final response = await _tripRepo.changeDriverCommission(
        percentage: percentage.ceil(),
      );
      emit(
        state.copyWith(
          status: TripStatus.changeDriverCommissionSuccess,
          successMessage: response,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: TripStatus.changeDriverCommissionFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }
}
