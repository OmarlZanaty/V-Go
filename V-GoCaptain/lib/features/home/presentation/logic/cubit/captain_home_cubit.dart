import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../../core/services/location_service.dart';
import '../../../../../core/services/realtime_service.dart';
import '../../../../../core/utils/app_constants.dart';
import '../../../data/models/trip_offer_model.dart';

part 'captain_home_state.dart';

class CaptainHomeCubit extends Cubit<CaptainHomeState> {
  final RealtimeService _realtime;
  final LocationService _location;

  StreamSubscription<Position>? _positionSub;
  Position? _lastPosition;

  /// Set by the shell to refresh the trips/earnings list after a completed trip.
  void Function()? onTripCompleted;

  CaptainHomeCubit(this._realtime, this._location)
      : super(const CaptainHomeState()) {
    _realtime.onTripOffer = _handleOffer;
    _realtime.onTripTaken = _handleTripTaken;
    _realtime.onConnectionLost = _handleConnectionLost;
    _realtime.onReconnected = _handleReconnected;
  }

  Future<void> goOnline() async {
    // Only start from a clean offline state (prevents double-connect on rapid taps).
    if (state.connection != CaptainConnection.offline) return;
    emit(state.copyWith(
        connection: CaptainConnection.connecting, clearError: true));

    final granted = await _location.ensurePermission();
    if (!granted) {
      emit(state.copyWith(
        connection: CaptainConnection.offline,
        error: 'يجب تفعيل إذن الموقع لاستقبال الرحلات',
      ));
      return;
    }

    try {
      await _realtime.connect();
      _lastPosition = await _location.currentPosition();
      await _realtime.updateDriverStatus(
        isAvailable: true,
        lat: _lastPosition?.latitude,
        lng: _lastPosition?.longitude,
      );
      _startLocationStream();
      emit(state.copyWith(connection: CaptainConnection.online));
    } catch (_) {
      await _realtime.disconnect();
      emit(state.copyWith(
        connection: CaptainConnection.offline,
        error: 'تعذّر الاتصال بالخادم، حاول مرة أخرى',
      ));
    }
  }

  Future<void> goOffline() async {
    await _positionSub?.cancel();
    _positionSub = null;
    try {
      await _realtime.updateDriverStatus(isAvailable: false);
      await _realtime.disconnect();
    } catch (_) {}
    emit(state.copyWith(
      connection: CaptainConnection.offline,
      clearOffer: true,
    ));
  }

  void _startLocationStream() {
    _positionSub?.cancel();
    _positionSub = _location.positionStream().listen((pos) {
      _lastPosition = pos;
      // Fire-and-forget but never let a failed push crash the stream.
      unawaited(_realtime
          .updateDriverStatus(
            isAvailable: !state.hasActiveTrip,
            lat: pos.latitude,
            lng: pos.longitude,
          )
          .catchError((_) {}));
    });
  }

  void _handleOffer(Map<dynamic, dynamic> raw) {
    if (state.hasActiveTrip) return; // already serving a trip
    final offer = TripOfferModel.fromMap(raw);
    if (offer.tripId.isEmpty) return;
    emit(state.copyWith(offer: offer));
  }

  void _handleTripTaken(String tripId) {
    if (state.offer?.tripId == tripId) {
      emit(state.copyWith(
          clearOffer: true, error: 'تم قبول الرحلة من كابتن آخر'));
    }
  }

  void _handleConnectionLost() {
    if (isClosed) return;
    if (state.connection == CaptainConnection.online) {
      emit(state.copyWith(connection: CaptainConnection.connecting));
    }
  }

  /// After an auto-reconnect, restore availability and the online UI.
  void _handleReconnected() {
    if (isClosed || state.connection == CaptainConnection.offline) return;
    unawaited(_realtime
        .updateDriverStatus(
          isAvailable: !state.hasActiveTrip,
          lat: _lastPosition?.latitude,
          lng: _lastPosition?.longitude,
        )
        .catchError((_) {}));
    emit(state.copyWith(connection: CaptainConnection.online));
  }

  Future<void> acceptOffer() async {
    final offer = state.offer;
    if (offer == null || state.isBusy) return;
    emit(state.copyWith(isBusy: true, clearError: true));
    try {
      final pos = _lastPosition ?? await _location.currentPosition();
      await _realtime.acceptTrip(
        tripId: offer.tripId,
        lat: pos.latitude,
        lng: pos.longitude,
      );
      emit(state.copyWith(
        activeTrip: offer,
        stage: TripStage.accepted,
        isBusy: false,
        clearOffer: true,
      ));
    } catch (_) {
      emit(state.copyWith(isBusy: false, error: 'تعذّر قبول الرحلة'));
    }
  }

  Future<void> rejectOffer() async {
    final offer = state.offer;
    if (offer == null) return;
    emit(state.copyWith(clearOffer: true));
    try {
      await _realtime.rejectTrip(offer.tripId);
    } catch (_) {}
  }

  Future<void> advanceStage() async {
    final trip = state.activeTrip;
    if (trip == null || state.isBusy) return;
    emit(state.copyWith(isBusy: true, clearError: true));
    try {
      switch (state.stage) {
        case TripStage.accepted:
          await _realtime.arrived(trip.tripId);
          emit(state.copyWith(stage: TripStage.arrived, isBusy: false));
        case TripStage.arrived:
          await _realtime.startTrip(trip.tripId);
          emit(state.copyWith(stage: TripStage.inProgress, isBusy: false));
        case TripStage.inProgress:
          await _realtime.endTrip(trip.tripId);
          emit(state.copyWith(
            stage: TripStage.completed,
            isBusy: false,
            clearActiveTrip: true,
          ));
          // Re-mark available for the next ride + refresh history/earnings.
          unawaited(_realtime
              .updateDriverStatus(
                isAvailable: true,
                lat: _lastPosition?.latitude,
                lng: _lastPosition?.longitude,
              )
              .catchError((_) {}));
          onTripCompleted?.call();
        case TripStage.completed:
          emit(state.copyWith(isBusy: false));
      }
    } catch (_) {
      emit(state.copyWith(isBusy: false, error: 'تعذّر تحديث حالة الرحلة'));
    }
  }

  @override
  Future<void> close() async {
    await _positionSub?.cancel();
    await _realtime.disconnect();
    return super.close();
  }
}
