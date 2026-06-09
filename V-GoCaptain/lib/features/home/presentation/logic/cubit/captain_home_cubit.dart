import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../../core/services/location_service.dart';
import '../../../../../core/services/realtime_service.dart';
import '../../../../../core/utils/app_constants.dart';
import '../../../../trips/data/models/trip_model.dart';
import '../../../../trips/data/repo/trip_repo.dart';
import '../../../data/models/trip_offer_model.dart';

part 'captain_home_state.dart';

class CaptainHomeCubit extends Cubit<CaptainHomeState> with WidgetsBindingObserver {
  final RealtimeService _realtime;
  final LocationService _location;
  final TripRepo _tripRepo;

  StreamSubscription<Position>? _positionSub;
  Position? _lastPosition;

  /// Set by the shell to refresh the trips/earnings list after a completed trip.
  void Function()? onTripCompleted;

  CaptainHomeCubit(this._realtime, this._location, this._tripRepo)
      : super(const CaptainHomeState()) {
    _realtime.onTripOffer = _handleOffer;
    _realtime.onTripTaken = _handleTripTaken;
    _realtime.onConnectionLost = _handleConnectionLost;
    _realtime.onReconnected = _handleReconnected;
    _realtime.onPaymentUpdated = _handlePaymentUpdated;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    // Coming back to the app (e.g. after the client paid by visa on their phone)
    // — re-check payment in case we missed the live event while backgrounded.
    if (lifecycle == AppLifecycleState.resumed) {
      unawaited(recheckActivePayment());
    }
  }

  /// Re-fetch the active trip's payment status and settle if it's already paid.
  /// Recovers from a missed TripPaymentUpdated event (backgrounded socket).
  Future<void> recheckActivePayment({bool showFeedback = false}) async {
    final trip = state.activeTrip;
    if (trip == null || state.activeTripPaid) return;
    if (showFeedback) emit(state.copyWith(isBusy: true, clearError: true));
    try {
      final trips = await _tripRepo.getMyTrips();
      final match = trips.where((t) => t.tripId == trip.tripId).toList();
      final paid = match.isNotEmpty && match.first.isPaid;
      if (isClosed) return;
      if (paid) {
        if (state.stage == TripStage.completed) {
          _finishTrip();
        } else {
          emit(state.copyWith(activeTripPaid: true, isBusy: false));
        }
      } else if (showFeedback) {
        emit(state.copyWith(
          isBusy: false,
          error: 'لم يكتمل دفع العميل بعد، يرجى المحاولة بعد إتمامه.',
        ));
      }
    } catch (_) {
      if (!isClosed && showFeedback) {
        emit(state.copyWith(isBusy: false, error: 'تعذّر التحقق من الدفع'));
      }
    }
  }

  /// Center the home map on the captain as soon as the screen opens — but only
  /// if permission is already granted, so we don't prompt before they go online.
  Future<void> initLocation() async {
    if (state.position != null) return;
    try {
      if (!await _location.hasPermission()) return;
      final pos = await _location.currentPosition();
      _lastPosition = pos;
      if (!isClosed) emit(state.copyWith(position: pos));
    } catch (_) {
      // Best-effort: a missing fix just leaves the map on its default center.
    }
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
      emit(state.copyWith(
          connection: CaptainConnection.online, position: _lastPosition));
      // Restore an in-progress trip first (so closing/reopening the app doesn't
      // strand a ride that can't be ended), then surface any waiting offer.
      await _restoreActiveTrip();
      unawaited(_loadPendingOffer());
    } catch (_) {
      await _realtime.disconnect();
      emit(state.copyWith(
        connection: CaptainConnection.offline,
        error: 'تعذّر الاتصال بالخادم، حاول مرة أخرى',
      ));
    }
  }

  /// Restore a trip the captain is already serving (Accepted/Arrived/InProgress)
  /// after an app restart, so it's never stranded with no way to advance/end it.
  Future<void> _restoreActiveTrip() async {
    if (state.hasActiveTrip) return;
    try {
      final trips = await _tripRepo.getMyTrips();
      final active = trips.where((t) => t.isActive).toList();
      if (active.isEmpty || isClosed || state.hasActiveTrip) return;
      final t = active.first;
      final stage = switch (t.status) {
        'Arrived' => TripStage.arrived,
        'InProgress' => TripStage.inProgress,
        _ => TripStage.accepted,
      };
      emit(state.copyWith(
        activeTrip: _toOffer(t),
        stage: stage,
        activeTripPaid: t.isPaid,
      ));
    } catch (_) {
      // Best-effort: failing to restore must not block going online.
    }
  }

  /// Pull a trip that's already waiting for a driver and surface it as an offer.
  /// Only the first one is shown (same card as a live offer); the captain can
  /// also pull-to-refresh implicitly by toggling online again.
  Future<void> _loadPendingOffer() async {
    if (state.hasActiveTrip || state.offer != null) return;
    try {
      final pending = await _tripRepo.getPendingTrips();
      if (isClosed || !state.isOnline) return;
      if (state.hasActiveTrip || state.offer != null || pending.isEmpty) return;
      emit(state.copyWith(offer: _toOffer(pending.first)));
    } catch (_) {
      // Best-effort: a failed pending fetch must not affect going online.
    }
  }

  TripOfferModel _toOffer(TripModel t) => TripOfferModel(
        tripId: t.tripId,
        price: t.price,
        start: TripPoint(
            lat: t.from.lat, lng: t.from.lng, address: t.from.address ?? ''),
        end: TripPoint(
            lat: t.to.lat, lng: t.to.lng, address: t.to.address ?? ''),
        client: TripClient(
          clientId: '',
          fullName: t.clientName,
          phoneNumber: t.clientPhone,
          profileImageUrl: t.clientImage,
          rating: 0,
        ),
        paymentMethod: t.paymentMethod,
      );

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
      if (!isClosed) emit(state.copyWith(position: pos)); // keep the map following
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
    // We may have missed a payment event while disconnected — re-check.
    unawaited(recheckActivePayment());
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
          // Keep the trip active at the completed stage so the captain must
          // settle payment before moving on (cash = confirm, online = auto).
          emit(state.copyWith(stage: TripStage.completed, isBusy: false));
          onTripCompleted?.call();
        case TripStage.completed:
          emit(state.copyWith(isBusy: false));
      }
    } catch (_) {
      emit(state.copyWith(isBusy: false, error: 'تعذّر تحديث حالة الرحلة'));
    }
  }

  /// Captain pressed "payment received" on a cash trip. Marks it paid on the
  /// server (which unlocks the rider) and then finishes up.
  Future<void> confirmCashPayment() async {
    final trip = state.activeTrip;
    if (trip == null || state.isBusy) return;
    emit(state.copyWith(isBusy: true, clearError: true));
    try {
      await _realtime.confirmCashPayment(trip.tripId);
      _finishTrip();
    } catch (_) {
      emit(state.copyWith(isBusy: false, error: 'تعذّر تأكيد الدفع، حاول مجددا'));
    }
  }

  /// Dismiss the completed panel once payment is already settled (e.g. the rider
  /// paid online).
  void finishTrip() => _finishTrip();

  /// Clear the served trip, go available again, and refresh history/earnings.
  void _finishTrip() {
    if (!state.hasActiveTrip) return;
    emit(state.copyWith(isBusy: false, clearActiveTrip: true));
    unawaited(_realtime
        .updateDriverStatus(
          isAvailable: true,
          lat: _lastPosition?.latitude,
          lng: _lastPosition?.longitude,
        )
        .catchError((_) {}));
    onTripCompleted?.call();
  }

  /// Backend says the active trip's payment is settled. If the ride is already
  /// completed, finish; otherwise remember it so the completed-stage button
  /// shows "done" instead of "confirm cash".
  void _handlePaymentUpdated() {
    if (isClosed || !state.hasActiveTrip) return;
    if (state.stage == TripStage.completed) {
      _finishTrip();
    } else {
      emit(state.copyWith(activeTripPaid: true));
    }
  }

  @override
  Future<void> close() async {
    WidgetsBinding.instance.removeObserver(this);
    await _positionSub?.cancel();
    await _realtime.disconnect();
    return super.close();
  }
}
