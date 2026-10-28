import 'dart:async';
import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../../core/services/location_service.dart';
import '../../../../../core/services/realtime_service.dart';
import '../../../../../core/utils/app_constants.dart';
import '../../../../finance/data/repo/finance_repo.dart';
import '../../../../trips/data/models/trip_model.dart';
import '../../../../trips/data/repo/trip_repo.dart';
import '../../../data/models/trip_offer_model.dart';

part 'captain_home_state.dart';

class CaptainHomeCubit extends Cubit<CaptainHomeState>
    with WidgetsBindingObserver {
  final RealtimeService _realtime;
  final LocationService _location;
  final TripRepo _tripRepo;
  final FinanceRepo _financeRepo;

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<DriverOnlineBlock>? _onlineBlockedSub;
  Position? _lastPosition;
  DriverOnlineBlock? _offlineAfterTripBlock;

  /// Set by the shell to refresh the trips/earnings list after a completed trip.
  void Function()? onTripCompleted;

  CaptainHomeCubit(
    this._realtime,
    this._location,
    this._tripRepo,
    this._financeRepo,
  ) : super(const CaptainHomeState()) {
    _realtime.onTripOffer = _handleOffer;
    _realtime.onTripTaken = _handleTripTaken;
    _realtime.onTripCancelled = _handleTripCancelled;
    _realtime.onConnectionLost = _handleConnectionLost;
    _realtime.onReconnected = _handleReconnected;
    _realtime.onPaymentUpdated = _handlePaymentUpdated;
    _realtime.onClientLocation = _handleClientLocation;
    _onlineBlockedSub = _realtime.onlineBlockedStream.listen(
      (block) => unawaited(_handleOnlineBlocked(block)),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  /// Rider's live GPS — only useful until pickup; ignored once the ride starts.
  void _handleClientLocation(double lat, double lng) {
    if (isClosed || !state.hasActiveTrip) return;
    if (state.stage != TripStage.accepted && state.stage != TripStage.arrived) {
      return;
    }
    emit(state.copyWith(clientLat: lat, clientLng: lng));
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
    if (trip == null || state.activeTripPaid || trip.isFreeRide) return;
    if (showFeedback) emit(state.copyWith(isBusy: true, clearError: true));
    try {
      // Trigger a server-side reconcile with Paymob first, so a card payment whose
      // webhook never arrived gets settled before we read the trip list.
      await _tripRepo.syncPayment(trip.tripId);
      if (isClosed) return;
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
        emit(
          state.copyWith(
            isBusy: false,
            error: 'لم يكتمل دفع العميل بعد، يرجى المحاولة بعد إتمامه.',
          ),
        );
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
    emit(
      state.copyWith(
        connection: CaptainConnection.connecting,
        clearError: true,
        clearOnlineBlock: true,
        clearOnlineBanner: true,
      ),
    );

    try {
      final eligibility = await _financeRepo.getEligibility();
      if (!eligibility.canGoOnline) {
        emit(
          state.copyWith(
            connection: CaptainConnection.offline,
            clearOffers: true,
            onlineBlock: DriverOnlineBlock(
              canGoOnline: eligibility.canGoOnline,
              code: eligibility.code,
              message: eligibility.message,
            ),
          ),
        );
        return;
      }
    } catch (_) {
      // Can't reach the check (network blip): carry on — the server refuses an
      // ineligible captain on the hub anyway and pushes DriverOnlineBlocked.
    }

    final granted = await _location.ensurePermission();
    if (!granted) {
      emit(
        state.copyWith(
          connection: CaptainConnection.offline,
          error: 'يجب تفعيل إذن الموقع لاستقبال الرحلات',
        ),
      );
      return;
    }

    try {
      // Socket + GPS fix in parallel — each can take seconds on mobile. A missing
      // fix must not block going online; the position stream fills it in.
      final positionFuture = _location.currentPosition().then<Position?>(
        (p) => p,
        onError: (_) => _lastPosition,
      );
      await _realtime.connect();
      _lastPosition = await positionFuture;
      await _realtime.updateDriverStatus(
        isAvailable: true,
        lat: _lastPosition?.latitude,
        lng: _lastPosition?.longitude,
      );
      _startLocationStream();
      emit(
        state.copyWith(
          connection: CaptainConnection.online,
          position: _lastPosition,
        ),
      );
      // Restore an in-progress trip first (so closing/reopening the app doesn't
      // strand a ride that can't be ended), then surface any waiting offer.
      await _restoreActiveTrip();
      unawaited(_loadPendingOffer());
    } catch (e) {
      log('goOnline failed: $e', name: 'CaptainHomeCubit');
      await _realtime.disconnect();
      emit(
        state.copyWith(
          connection: CaptainConnection.offline,
          error: 'تعذّر الاتصال بالخادم، حاول مرة أخرى',
        ),
      );
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
      emit(
        state.copyWith(
          clearOffers: true,
          activeTrip: _toOffer(t),
          stage: stage,
          activeTripPaid: t.isPaid,
        ),
      );
    } catch (_) {
      // Best-effort: failing to restore must not block going online.
    }
  }

  Future<void> _loadPendingOffer() async {
    if (state.hasActiveTrip) return;
    try {
      final pending = await _tripRepo.getPendingTrips();
      if (isClosed || !state.isOnline) return;
      if (state.hasActiveTrip || pending.isEmpty) return;
      final offers = [...state.offers];
      final tripIds = offers.map((offer) => offer.tripId).toSet();
      for (final offer in pending.map(_toOffer)) {
        if (offer.tripId.isNotEmpty && tripIds.add(offer.tripId)) {
          offers.add(offer);
        }
      }
      emit(state.copyWith(offers: offers));
    } catch (_) {
      // Best-effort: a failed pending fetch must not affect going online.
    }
  }

  TripOfferModel _toOffer(TripModel t) => TripOfferModel(
    tripId: t.tripId,
    price: t.price,
    start: TripPoint(
      lat: t.from.lat,
      lng: t.from.lng,
      address: t.from.address ?? '',
    ),
    end: TripPoint(lat: t.to.lat, lng: t.to.lng, address: t.to.address ?? ''),
    client: TripClient(
      clientId: '',
      fullName: t.clientName,
      phoneNumber: t.clientPhone,
      profileImageUrl: t.clientImage,
      rating: 0,
    ),
    paymentMethod: t.paymentMethod,
    isFreeRide: t.isFreeRide,
    discountAmount: t.discountAmount,
  );

  Future<void> goOffline() async {
    await _positionSub?.cancel();
    _positionSub = null;
    try {
      await _realtime.updateDriverStatus(isAvailable: false);
      await _realtime.disconnect();
    } catch (_) {}
    emit(
      state.copyWith(connection: CaptainConnection.offline, clearOffers: true),
    );
  }

  Future<void> _handleOnlineBlocked(DriverOnlineBlock block) async {
    if (isClosed || block.canGoOnline) return;
    if (state.hasActiveTrip) {
      _offlineAfterTripBlock = block;
      emit(
        state.copyWith(
          clearOffers: true,
          onlineBanner:
              block.message ?? 'لازم تراجع حالة حسابك قبل استقبال رحلات جديدة.',
        ),
      );
      return;
    }
    await _goOfflineBecauseBlocked(block);
  }

  Future<void> _goOfflineBecauseBlocked(DriverOnlineBlock block) async {
    await _positionSub?.cancel();
    _positionSub = null;
    try {
      await _realtime.updateDriverStatus(isAvailable: false);
      await _realtime.disconnect();
    } catch (_) {}
    if (!isClosed) {
      emit(
        state.copyWith(
          connection: CaptainConnection.offline,
          clearOffers: true,
          onlineBlock: block,
        ),
      );
    }
  }

  DateTime? _lastPushAt;

  void _startLocationStream() {
    _positionSub?.cancel();
    // Fast fixes so the rider sees the captain move smoothly during a trip;
    // pushes are throttled below so idle captains don't flood the server.
    _positionSub = _location
        .positionStream(
          distanceFilter: 3,
          interval: const Duration(seconds: 1),
          keepAliveInBackground: true,
        )
        .listen((pos) {
          _lastPosition = pos;
          if (!isClosed)
            emit(state.copyWith(position: pos)); // keep the map following
          final now = DateTime.now();
          final minGap = state.hasActiveTrip
              ? const Duration(milliseconds: 1500)
              : const Duration(seconds: 10);
          final last = _lastPushAt;
          if (last != null && now.difference(last) < minGap) return;
          _lastPushAt = now;
          // Fire-and-forget but never let a failed push crash the stream.
          unawaited(
            _realtime
                .updateDriverStatus(
                  isAvailable: !state.hasActiveTrip,
                  lat: pos.latitude,
                  lng: pos.longitude,
                )
                .catchError((_) {}),
          );
        });
  }

  /// Immediately push the captain's current location for the active trip so the
  /// rider's map updates without waiting for the movement-filtered stream. Safe
  /// to fire-and-forget; failures never disrupt the trip flow.
  Future<void> _pushActiveTripLocation() async {
    if (!state.hasActiveTrip) return;
    try {
      final pos = _lastPosition ?? await _location.currentPosition();
      _lastPosition = pos;
      await _realtime.updateDriverStatus(
        isAvailable: false,
        lat: pos.latitude,
        lng: pos.longitude,
      );
    } catch (_) {
      // Best-effort seed; the position stream will follow up on movement.
    }
  }

  void _handleOffer(Map<dynamic, dynamic> raw) {
    if (state.hasActiveTrip) return; // already serving a trip
    final offer = TripOfferModel.fromMap(raw);
    if (offer.tripId.isEmpty ||
        state.offers.any((existing) => existing.tripId == offer.tripId)) return;
    emit(state.copyWith(offers: [...state.offers, offer]));
  }

  void _handleTripTaken(String tripId) {
    if (state.offers.any((offer) => offer.tripId == tripId)) {
      emit(
        state.copyWith(
          offers: state.offers.where((offer) => offer.tripId != tripId).toList(),
          error: 'تم قبول الرحلة من كابتن آخر',
        ),
      );
    }
  }

  // Client cancelled the trip — clear whichever we hold for it (offer if not yet
  // accepted, or the active ride if already accepted) so it doesn't "ghost".
  void _handleTripCancelled(String tripId) {
    if (isClosed) return;
    if (state.offers.any((offer) => offer.tripId == tripId)) {
      emit(
        state.copyWith(
          offers: state.offers.where((offer) => offer.tripId != tripId).toList(),
          error: 'تم إلغاء الرحلة من قِبل العميل',
        ),
      );
      return;
    }
    if (state.activeTrip?.tripId == tripId) {
      emit(state.copyWith(error: 'تم إلغاء الرحلة من قِبل العميل'));
      _finishTrip();
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
    unawaited(
      _realtime
          .updateDriverStatus(
            isAvailable: !state.hasActiveTrip,
            lat: _lastPosition?.latitude,
            lng: _lastPosition?.longitude,
          )
          .catchError((_) {}),
    );
    emit(state.copyWith(connection: CaptainConnection.online));
    // We may have missed a payment event while disconnected — re-check.
    unawaited(recheckActivePayment());
  }

  Future<void> acceptOffer(String tripId) async {
    if (state.hasActiveTrip || state.isBusy) return;
    final matches = state.offers.where((offer) => offer.tripId == tripId);
    if (matches.isEmpty) return;
    final offer = matches.first;
    emit(state.copyWith(isBusy: true, clearError: true));
    try {
      final pos = _lastPosition ?? await _location.currentPosition();
      _lastPosition = pos;
      await _realtime.acceptTrip(
        tripId: offer.tripId,
        lat: pos.latitude,
        lng: pos.longitude,
      );
      emit(
        state.copyWith(
          activeTrip: offer,
          stage: TripStage.accepted,
          isBusy: false,
          clearOffers: true,
        ),
      );
      // Seed the rider's live tracking immediately. The position stream only
      // emits after 15m of movement (distanceFilter), so without this push the
      // captain marker wouldn't appear on the client until the captain moved.
      // isAvailable:false makes the backend forward this to the trip's client.
      unawaited(_pushActiveTripLocation());
    } on HubCallRejected catch (e) {
      // Cancelled by the client or taken by another captain: drop the offer.
      emit(
        state.copyWith(
          isBusy: false,
          offers: state.offers.where((offer) => offer.tripId != tripId).toList(),
          error: 'الرحلة لم تعد متاحة — ${e.message ?? 'تم إلغاؤها'}',
        ),
      );
    } catch (_) {
      emit(state.copyWith(isBusy: false, error: 'تعذّر قبول الرحلة'));
    }
  }

  Future<void> rejectOffer(String tripId) async {
    if (state.isBusy) return;
    emit(state.copyWith(
      offers: state.offers.where((offer) => offer.tripId != tripId).toList(),
    ));
  }

  Future<void> cancelActiveTrip() async {
    final trip = state.activeTrip;
    if (trip == null || state.isBusy ||
        (state.stage != TripStage.accepted && state.stage != TripStage.arrived)) {
      return;
    }
    emit(state.copyWith(isBusy: true, clearError: true));
    try {
      await _realtime.cancelAcceptedTrip(trip.tripId);
      if (isClosed) return;
      _finishTrip(notifyCompleted: false);
    } on HubCallRejected catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        isBusy: false,
        error: e.message ?? 'تعذّر إلغاء الرحلة',
      ));
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(isBusy: false, error: 'تعذّر إلغاء الرحلة'));
    }
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
          unawaited(_pushActiveTripLocation());
        case TripStage.arrived:
          await _realtime.startTrip(trip.tripId);
          emit(
            state.copyWith(
              stage: TripStage.inProgress,
              isBusy: false,
              clearClientLocation: true,
            ),
          );
          // Trip just started → target flips to the destination; seed a location
          // so the client's route/marker updates right away.
          unawaited(_pushActiveTripLocation());
        case TripStage.inProgress:
          await _realtime.endTrip(trip.tripId);
          // Keep the trip active at the completed stage so the captain must
          // settle payment before moving on (cash = confirm, online = auto).
          emit(
            state.copyWith(
              stage: TripStage.completed,
              isBusy: false,
              activeTripPaid: trip.isFreeRide || state.activeTripPaid,
            ),
          );
          onTripCompleted?.call();
        case TripStage.completed:
          emit(state.copyWith(isBusy: false));
      }
    } on HubCallRejected catch (e) {
      emit(
        state.copyWith(
          isBusy: false,
          error: e.message ?? 'تعذّر تحديث حالة الرحلة',
        ),
      );
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
      emit(
        state.copyWith(isBusy: false, error: 'تعذّر تأكيد الدفع، حاول مجددا'),
      );
    }
  }

  /// Dismiss the completed panel once payment is already settled (e.g. the rider
  /// paid online).
  void finishTrip() => _finishTrip();

  /// Visa escape hatch: the client refused / failed to pay by card. Report it
  /// to the server (which releases the rider's app from its payment screen),
  /// then close out the trip. The trip stays unpaid (no Paid record).
  Future<void> markVisaRefusedAndFinish() async {
    final trip = state.activeTrip;
    if (trip == null || state.isBusy) return;
    emit(state.copyWith(isBusy: true, clearError: true));
    try {
      await _realtime.reportPaymentRefused(trip.tripId);
      _finishTrip();
    } catch (_) {
      emit(
        state.copyWith(
          isBusy: false,
          error: 'تعذّر تسجيل رفض الدفع، حاول مجددا',
        ),
      );
    }
  }

  /// Clear the served trip, go available again, and refresh history/earnings.
  void _finishTrip({bool notifyCompleted = true}) {
    if (!state.hasActiveTrip) return;
    emit(state.copyWith(isBusy: false, clearActiveTrip: true));
    final block = _offlineAfterTripBlock;
    if (block != null) {
      _offlineAfterTripBlock = null;
      unawaited(_goOfflineBecauseBlocked(block));
      if (notifyCompleted) onTripCompleted?.call();
      return;
    }
    unawaited(
      _realtime
          .updateDriverStatus(
            isAvailable: true,
            lat: _lastPosition?.latitude,
            lng: _lastPosition?.longitude,
          )
          .catchError((_) {}),
    );
    if (notifyCompleted) onTripCompleted?.call();
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
    await _onlineBlockedSub?.cancel();
    await _realtime.disconnect();
    return super.close();
  }
}
