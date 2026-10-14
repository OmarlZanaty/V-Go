import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/errors/exception.dart';
import '../../../../../core/utils/app_constants.dart';
import '../../../../../core/utils/model/current_trip_model.dart';
import '../../../../../core/utils/model/location_model.dart';
import '../../../data/model/fare_quote_model.dart';
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

  /// Asks the server for the fare of [from] → [to]. Repeated calls for the
  /// same route (~10 m) are ignored, so this is safe to call on every rebuild.
  Future<double?> getFareQuote({
    required LocationModel from,
    required LocationModel to,
    bool force = false,
  }) async {
    final key = _quoteKey(from, to);
    if (!force &&
        key == state.quoteKey &&
        (state.status.isFareQuoteLoading || state.status.isFareQuoteSuccess)) {
      return state.status.isFareQuoteSuccess ? state.tripPrice : null;
    }
    emit(state.copyWith(status: TripStatus.fareQuoteLoading, quoteKey: key));
    try {
      final quote = await _tripRepo.getFareQuote(from: from, to: to);
      // A newer route was requested meanwhile; its result wins.
      if (isClosed || state.quoteKey != key) return null;
      emit(
        state.copyWith(
          status: TripStatus.fareQuoteSuccess,
          tripPrice: quote.riderPrice,
          fareQuote: quote,
        ),
      );
      return quote.riderPrice;
    } catch (e) {
      if (isClosed || state.quoteKey != key) return null;
      emit(
        state.copyWith(
          status: TripStatus.fareQuoteFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
      return null;
    }
  }

  static String _quoteKey(LocationModel from, LocationModel to) =>
      '${from.latitude.toStringAsFixed(4)},${from.longitude.toStringAsFixed(4)};'
      '${to.latitude.toStringAsFixed(4)},${to.longitude.toStringAsFixed(4)}';

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
