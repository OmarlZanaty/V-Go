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

  /// One-shot error message for the UI to surface.
  final String? error;

  const CaptainHomeState({
    this.connection = CaptainConnection.offline,
    this.offer,
    this.activeTrip,
    this.stage = TripStage.accepted,
    this.isBusy = false,
    this.error,
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
    String? error,
    bool clearError = false,
  }) {
    return CaptainHomeState(
      connection: connection ?? this.connection,
      offer: clearOffer ? null : (offer ?? this.offer),
      activeTrip: clearActiveTrip ? null : (activeTrip ?? this.activeTrip),
      stage: stage ?? this.stage,
      isBusy: isBusy ?? this.isBusy,
      error: clearError ? null : error,
    );
  }

  @override
  List<Object?> get props =>
      [connection, offer?.tripId, activeTrip?.tripId, stage, isBusy, error];
}
