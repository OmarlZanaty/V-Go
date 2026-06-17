import 'dart:async';
import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/errors/exception.dart';
import '../../../../../core/helpers/extensions.dart';
import '../../../../../core/helpers/play_notification_sound.dart';
import '../../../../../core/services/trip_service.dart';
import '../../../../../core/utils/app_constants.dart';
import '../../../../../core/utils/model/current_trip_model.dart';
import '../../../data/model/new_trip_requested_for_driver_model.dart';
import '../../../data/model/payment_status_model.dart';
import '../../../data/model/trip_approved_for_client_model.dart';
import '../../../data/model/trip_request_model.dart';

part 'realtime_trip_state.dart';

class RealTimeTripCubit extends Cubit<RealTimeTripState>
    with WidgetsBindingObserver {
  final TripService _tripService;
  bool _lifecycleObserved = false;

  RealTimeTripCubit(this._tripService) : super(const RealTimeTripState());

  /// When the app returns to the foreground, re-pull the current trip — covers
  /// the case where events were missed while backgrounded but the socket never
  /// fully dropped (so onreconnected wouldn't fire).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_tripService.requestCurrentTrip());
    }
  }

  Future<void> connect() async {
    emit(state.copyWith(status: RealTimeTripStatus.connecting));
    try {
      await _tripService.connect();
      emit(state.copyWith(status: RealTimeTripStatus.connected));
      _initTripListeners();
      // Recover trip state on every (re)connect so the UI never gets stuck on a
      // stale "searching" screen after missing a live event while disconnected.
      _tripService.onReconnected =
          () => unawaited(_tripService.requestCurrentTrip());
      unawaited(_tripService.requestCurrentTrip());
      if (!_lifecycleObserved) {
        WidgetsBinding.instance.addObserver(this);
        _lifecycleObserved = true;
      }
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: RealTimeTripStatus.error,
          errorMessage: 'حدث خطأ ما , يرجى المحاولة مجددا',
        ),
      );
    }
  }

  Future<void> requestTrip(TripRequestModel tripRequest) async {
    emit(state.copyWith(status: RealTimeTripStatus.requestTripLoading));
    try {
      final tripId = await _tripService.requestTrip(tripRequest);
      emit(
        state.copyWith(
          status: RealTimeTripStatus.requestTripSuccess,
          tripId: tripId,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: RealTimeTripStatus.requestTripFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> approveAndAssignDriverToTrip(
    String tripId,
    String driverLat,
    String driverLng,
  ) async {
    emit(state.copyWith(status: RealTimeTripStatus.tripApproveLoading));
    try {
      await _tripService.approveAndAssignDriverToTrip(
        tripId,
        driverLat,
        driverLng,
      );
      emit(
        state.copyWith(
          status: RealTimeTripStatus.tripApproveSuccess,
          successMessage: 'تم قبول الطلب بنجاح',
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: RealTimeTripStatus.tripApproveFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> arrivedDriverToClient(String tripId) async {
    emit(
      state.copyWith(status: RealTimeTripStatus.arrivedDriverToClientLoading),
    );
    try {
      await _tripService.arrivedDriverToClient(tripId);
      emit(
        state.copyWith(status: RealTimeTripStatus.arrivedDriverToClientSuccess),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: RealTimeTripStatus.arrivedDriverToClientFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> startTrip(String tripId) async {
    emit(state.copyWith(status: RealTimeTripStatus.startTripLoading));
    try {
      await _tripService.startTrip(tripId);
      emit(state.copyWith(status: RealTimeTripStatus.startTripSuccess));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: RealTimeTripStatus.startTripFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> endTrip(String tripId) async {
    emit(state.copyWith(status: RealTimeTripStatus.endTripLoading));
    try {
      await _tripService.endTrip(tripId);
      emit(
        state.copyWith(
          status: RealTimeTripStatus.endTripSuccess,
          successMessage: 'تم انهاء الرحلة بنجاح',
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: RealTimeTripStatus.endTripFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> cancelTrip({String? tripId, String? reason}) async {
    emit(state.copyWith(status: RealTimeTripStatus.cancelTripLoading));
    try {
      await _tripService.cancelTrip(
        tripId ?? state.tripId,
        AppConstants.kUserId,
        reason: reason,
      );
      emit(
        state.copyWith(
          status: RealTimeTripStatus.cancelTripSuccess,
          resetCurrentTrip: true,
          successMessage: 'تم إلغاء الرحلة بنجاح',
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: RealTimeTripStatus.cancelTripFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> disconnect() async {
    emit(state.copyWith(status: RealTimeTripStatus.disconnected));
    try {
      await _tripService.disconnect();
      emit(state.copyWith(status: RealTimeTripStatus.disconnected));
    } catch (e) {
      emit(
        state.copyWith(
          status: RealTimeTripStatus.error,
          errorMessage: 'حدث خطأ ما , يرجى المحاولة مجددا',
        ),
      );
    }
  }

  Future<void> payTripInCash(String tripId, String driverId) async {
    emit(state.copyWith(status: RealTimeTripStatus.payTripInCashLoading));
    try {
      await _tripService.payTripInCash(tripId, driverId);
      emit(
        state.copyWith(
          status: RealTimeTripStatus.payTripInCashSuccess,
          successMessage: 'تم دفع الرحلة بنجاح',
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: RealTimeTripStatus.payTripInCashFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  void _initTripListeners() {
    _listenForTripApprovedForClient();
    _listenForTripStartedForClient();
    _listenForTripEndedForClient();
    _listenForClientArrivedTrip();
    _listenForNewTripRequestedForDriver();
    _listenForTripStartedForDriver();
    _listenForTripEndedForDriver();
    _listenForDriverArrivedTrip();
    _listenForTripCancelledByClient();
    _listenForReceivedPendingTrips();
    _listenForReceiveCurrentTrip();
    _listenForTripCancelledForTripDriver();
    _listenForTripTakenByAnotherDriver();
    _listenForTripPaymentUpdated();
    _listenForTripCancelledForClient();
    _listenForReceiveDriverLocation();
  }

  void _listenForReceiveDriverLocation() {
    _tripService.receiveDriverLocation = (data) {
      if (data.isNullOrEmpty()) return;
      final map = data![0] as Map<String, dynamic>;
      final lat = (map['lat'] ?? map['Lat']) as num?;
      final lng = (map['lng'] ?? map['Lng']) as num?;
      if (lat == null || lng == null) return;
      emit(
        state.copyWith(
          status: RealTimeTripStatus.driverLocationReceived,
          driverLat: lat.toDouble(),
          driverLng: lng.toDouble(),
        ),
      );
    };
  }

  void _listenForTripApprovedForClient() {
    _tripService.tripApprovedForClient = (data) {
      if (data.isNullOrEmpty()) return;
      final trip = TripApprovedForClientModel.fromJson(
        data![0] as Map<String, dynamic>,
      );
      emit(
        state.copyWith(
          status: RealTimeTripStatus.tripApprovedForClientReceived,
          tripApprovedForClient: trip,
          tripStatus: trip.status,
        ),
      );
      playNotificationSound(SoundType.accept);
    };
  }

  void _listenForNewTripRequestedForDriver() {
    _tripService.newTripRequestedForDriver = (data) {
      if (data.isNullOrEmpty()) return;

      final newTrip = NewTripRequestedForDriverModel.fromJson(
        data![0] as Map<String, dynamic>,
      );
      final updatedList = List<NewTripRequestedForDriverModel>.from(
        state.tripRequestedListForDriver,
      )..add(newTrip);
      emit(
        state.copyWith(
          status: RealTimeTripStatus.newRequestedTripsForDriver,
          tripRequestedListForDriver: updatedList,
        ),
      );
      playNotificationSound(SoundType.free);
    };
  }

  void _listenForReceivedPendingTrips() {
    _tripService.receivePendingTrips = (data) {
      if (data.isNullOrEmpty()) return;
      final receivedPendingTrips = (data as List<dynamic>)
          .map(
            (item) => NewTripRequestedForDriverModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList();

      final updatedList = List<NewTripRequestedForDriverModel>.from(
        state.tripRequestedListForDriver,
      )..addAll(receivedPendingTrips);

      emit(
        state.copyWith(
          status: RealTimeTripStatus.newRequestedTripsForDriver,
          tripRequestedListForDriver: updatedList,
        ),
      );
    };
  }

  void _listenForReceiveCurrentTrip() {
    _tripService.receiveCurrentTrip = (data) {
      if (data.isNullOrEmpty()) return;
      final currentTrip = CurrentTripModel.fromJson(
        data![0] as Map<String, dynamic>,
      );
      emit(
        state.copyWith(
          status: RealTimeTripStatus.currentTripReceived,
          currentTrip: currentTrip,
          // Keep state.tripId in sync with the recovered trip so cancel/pay
          // target the right trip after a reconnect/resume (otherwise a
          // recovered pending ride cancels with an empty id → 404 → stuck).
          tripId: currentTrip.tripId,
          tripStatus: currentTrip.tripStatus,
          paymentStatusModel: PaymentStatusModel(
            paymentMessage: '',
            paymentStatus: currentTrip.isPaid ? 'Paid' : 'Pending',
          ),
        ),
      );
    };
  }

  void _listenForTripStartedForClient() {
    _tripService.tripStartedForClient = (data) {
      if (data.isNullOrEmpty()) return;
      final tripStatus = (data![0] as Map<String, dynamic>)['status'] as String;
      emit(
        state.copyWith(
          status: RealTimeTripStatus.tripStartedForClientReceived,
          tripStatus: tripStatus,
        ),
      );
      playNotificationSound(SoundType.begin);
    };
  }

  void _listenForTripStartedForDriver() {
    _tripService.tripStartedForDriver = (data) {
      if (data.isNullOrEmpty()) return;
      final tripStatus = (data![0] as Map<String, dynamic>)['status'] as String;
      emit(
        state.copyWith(
          status: RealTimeTripStatus.tripStartedForDriverReceived,
          tripStatus: tripStatus,
        ),
      );
    };
  }

  void _listenForTripEndedForClient() {
    _tripService.tripEndedForClient = (data) {
      if (data.isNullOrEmpty()) return;
      final tripStatus = (data![0] as Map<String, dynamic>)['status'] as String;
      emit(
        state.copyWith(
          status: RealTimeTripStatus.tripEndedForClientReceived,
          tripStatus: tripStatus,
          resetCurrentTrip: true,
        ),
      );
      playNotificationSound(SoundType.accept);
    };
  }

  void _listenForTripEndedForDriver() {
    _tripService.tripEndedForDriver = (data) {
      if (data.isNullOrEmpty()) return;
      final tripStatus = (data![0] as Map<String, dynamic>)['status'] as String;
      emit(
        state.copyWith(
          status: RealTimeTripStatus.tripEndedForDriverReceived,
          tripStatus: tripStatus,
          resetCurrentTrip: true,
        ),
      );
      removeTripFromList((data[0] as Map<String, dynamic>)['tripId']);
    };
  }

  void _listenForClientArrivedTrip() {
    _tripService.clientArrivedTrip = (data) {
      if (data.isNullOrEmpty()) return;
      final tripStatus = (data![0] as Map<String, dynamic>)['status'] as String;
      emit(
        state.copyWith(
          status: RealTimeTripStatus.clientArrivedTripReceived,
          tripStatus: tripStatus,
        ),
      );
      playNotificationSound(SoundType.bell);
    };
  }

  void _listenForDriverArrivedTrip() {
    _tripService.driverArrivedTrip = (data) {
      if (data.isNullOrEmpty()) return;
      final tripStatus = (data![0] as Map<String, dynamic>)['status'] as String;
      emit(
        state.copyWith(
          status: RealTimeTripStatus.driverArrivedTripReceived,
          tripStatus: tripStatus,
        ),
      );
    };
  }

  void _listenForTripCancelledByClient() {
    _tripService.tripCanceledByClient = (data) {
      if (data.isNullOrEmpty()) return;
      final tripStatus = (data![0] as Map<String, dynamic>)['status'] as String;
      emit(
        state.copyWith(
          status: RealTimeTripStatus.tripCanceledReceived,
          resetCurrentTrip: true,
          tripStatus: tripStatus,
        ),
      );
      removeTripFromList((data[0] as Map<String, dynamic>)['tripId']);
    };
  }

  void _listenForTripCancelledForClient() {
    _tripService.tripCanceledForClient = (data) {
      if (data.isNullOrEmpty()) return;
      final tripStatus = (data![0] as Map<String, dynamic>)['status'] as String;
      emit(
        state.copyWith(
          status: RealTimeTripStatus.tripCanceledReceived,
          resetCurrentTrip: true,
          tripStatus: tripStatus,
        ),
      );
    };
  }

  void _listenForTripCancelledForTripDriver() {
    _tripService.tripCanceledForTripDriver = (data) {
      if (data.isNullOrEmpty()) return;
      final tripStatus = (data![0] as Map<String, dynamic>)['status'] as String;
      emit(
        state.copyWith(
          status: RealTimeTripStatus.tripCanceledReceived,
          resetCurrentTrip: true,
          tripStatus: tripStatus,
        ),
      );
      removeTripFromList((data[0] as Map<String, dynamic>)['tripId']);
      playNotificationSound(SoundType.cancel);
    };
  }

  void _listenForTripTakenByAnotherDriver() {
    _tripService.tripTakenByAnotherDriver = (data) {
      if (data.isNullOrEmpty()) return;
      final tripId = (data![0] as Map<String, dynamic>)['tripId'] as String;
      emit(
        state.copyWith(
          status: RealTimeTripStatus.tripCanceledReceived,
          tripStatus: 'Canceled',
        ),
      );
      removeTripFromList((tripId));
    };
  }

  void _listenForTripPaymentUpdated() {
    _tripService.tripPaymentUpdated = (data) {
      log('payment data : $data');
      if (data.isNullOrEmpty()) return;
      final paymentModel = PaymentStatusModel.fromJson(
        data![0] as Map<String, dynamic>,
      );
      emit(
        state.copyWith(
          status: RealTimeTripStatus.tripPaymentUpdatedReceived,
          paymentStatusModel: paymentModel,
        ),
      );
    };
  }

  // used in 2 cancel trip and completed trips
  void removeTripFromList(String tripId) {
    final updatedList = state.tripRequestedListForDriver
        .where((element) => element.tripId != tripId)
        .toList();
    emit(
      state.copyWith(
        status: RealTimeTripStatus.newRequestedTripsForDriver,
        tripRequestedListForDriver: updatedList,
      ),
    );
  }

  void updateTripStatus(String status) {
    emit(
      state.copyWith(
        tripStatus: status,
        status: RealTimeTripStatus.tripApprovedForClientReceived,
      ),
    );
  }

  void setTripPrice(double price) {
    emit(state.copyWith(tripPrice: price));
  }

  @override
  Future<void> close() {
    if (_lifecycleObserved) WidgetsBinding.instance.removeObserver(this);
    _tripService.dispose();
    return super.close();
  }
}
