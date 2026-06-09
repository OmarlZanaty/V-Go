part of 'captain_home_cubit.dart';

enum CaptainConnection { offline, connecting, online }

class CaptainHomeState extends Equatable {
  /// Connection / availability status.
  final CaptainConnection connection;

  /// A pending offer awaiting accept/reject (null when none).
  final TripOfferModel? offer;

  /// The trip currently being served (null when idle).
  final TripOfferModel? activeTrip;

  /// Lifecycle stage of [activeTrip].
  final TripStage stage;

  /// True while an async action (accept/arrive/start/end) is in flight.
  final bool isBusy;

  /// True once the active trip's payment is settled (cash confirmed by the
  /// captain, or the rider paid online). Drives the completed-stage button.
  final bool activeTripPaid;

  /// One-shot error message for the UI to surface.
  final String? error;

  /// The captain's latest known location (for the home map). Null until the
  /// first GPS fix is available.
  final Position? position;

  const CaptainHomeState({
    this.connection = CaptainConnection.offline,
    this.offer,
    this.activeTrip,
    this.stage = TripStage.accepted,
    this.isBusy = false,
    this.activeTripPaid = false,
    this.error,
    this.position,
  });

  bool get isOnline => connection == CaptainConnection.online;
  bool get hasActiveTrip => activeTrip != null;

  CaptainHomeState copyWith({
    CaptainConnection? connection,
    TripOfferModel? offer,
    bool clearOffer = false,
    TripOfferModel? activeTrip,
    bool clearActiveTrip = false,
    TripStage? stage,
    bool? isBusy,
    bool? activeTripPaid,
    String? error,
    bool clearError = false,
    Position? position,
  }) {
    return CaptainHomeState(
      connection: connection ?? this.connection,
      offer: clearOffer ? null : (offer ?? this.offer),
      activeTrip: clearActiveTrip ? null : (activeTrip ?? this.activeTrip),
      stage: stage ?? this.stage,
      isBusy: isBusy ?? this.isBusy,
      activeTripPaid: clearActiveTrip ? false : (activeTripPaid ?? this.activeTripPaid),
      error: clearError ? null : error,
      position: position ?? this.position,
    );
  }

  @override
  List<Object?> get props => [
        connection,
        offer?.tripId,
        activeTrip?.tripId,
        stage,
        isBusy,
        activeTripPaid,
        error,
        position?.latitude,
        position?.longitude,
      ];
}
