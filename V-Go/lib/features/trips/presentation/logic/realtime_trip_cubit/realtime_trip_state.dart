part of 'realtime_trip_cubit.dart';

enum RealTimeTripStatus {
  initial,
  connecting,
  connected,
  disconnected,
  requestTripLoading,
  requestTripSuccess,
  requestTripFailure,
  tripApproveLoading,
  tripApproveSuccess,
  tripApproveFailure,
  rejectTripLoading,
  rejectTripSuccess,
  rejectTripFailure,
  startTripLoading,
  startTripSuccess,
  startTripFailure,
  endTripLoading,
  endTripSuccess,
  endTripFailure,
  cancelTripLoading,
  cancelTripSuccess,
  cancelTripFailure,
  tripApprovedForClientReceived,
  newRequestedTripsForDriver,
  tripStartedForClientReceived,
  tripStartedForDriverReceived,
  tripEndedForClientReceived,
  tripEndedForDriverReceived,
  tripCanceledReceived,
  arrivedDriverToClientLoading,
  arrivedDriverToClientSuccess,
  arrivedDriverToClientFailure,
  driverArrivedTripReceived,
  clientArrivedTripReceived,
  currentTripReceived,
  tripPaymentUpdatedReceived,
  driverLocationReceived,
  payTripInCashLoading,
  payTripInCashSuccess,
  payTripInCashFailure,
  error,
}

class RealTimeTripState extends Equatable {
  final RealTimeTripStatus status;
  final String errorMessage;
  final String successMessage;
  final String tripId;
  final TripApprovedForClientModel? tripApprovedForClient;
  final List<NewTripRequestedForDriverModel> tripRequestedListForDriver;
  final String tripStatus;
  final CurrentTripModel? currentTrip;
  final List<CurrentTripModel> currentTripList;
  final double tripPrice;
  final PaymentStatusModel? paymentStatusModel;
  // Live captain location during an active trip.
  final double? driverLat;
  final double? driverLng;

  const RealTimeTripState({
    this.status = RealTimeTripStatus.initial,
    this.errorMessage = 'حدث خطأ ما , يرجى المحاولة مجددا',
    this.successMessage = '',
    this.tripId = '',
    this.tripApprovedForClient,
    this.tripRequestedListForDriver = const [],
    this.currentTripList = const [],
    this.tripStatus = 'Pending',
    this.currentTrip,
    this.tripPrice = 0.0,
    this.paymentStatusModel,
    this.driverLat,
    this.driverLng,
  });

  RealTimeTripState copyWith({
    RealTimeTripStatus? status,
    String? errorMessage,
    String? successMessage,
    String? tripId,
    String? tripStatus,
    TripApprovedForClientModel? tripApprovedForClient,
    List<NewTripRequestedForDriverModel>? tripRequestedListForDriver,
    CurrentTripModel? currentTrip,
    List<CurrentTripModel>? currentTripList,
    bool? resetCurrentTrip,
    double? tripPrice,
    PaymentStatusModel? paymentStatusModel,
    double? driverLat,
    double? driverLng,
  }) {
    return RealTimeTripState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      successMessage: successMessage ?? this.successMessage,
      tripId: tripId ?? this.tripId,
      tripStatus: tripStatus ?? this.tripStatus,
      tripApprovedForClient:
          tripApprovedForClient ?? this.tripApprovedForClient,
      tripRequestedListForDriver:
          tripRequestedListForDriver ?? this.tripRequestedListForDriver,
      currentTrip: resetCurrentTrip == true
          ? null
          : currentTrip ?? this.currentTrip,
      currentTripList: currentTripList ?? this.currentTripList,
      tripPrice: tripPrice ?? this.tripPrice,
      paymentStatusModel: paymentStatusModel ?? this.paymentStatusModel,
      driverLat: driverLat ?? this.driverLat,
      driverLng: driverLng ?? this.driverLng,
    );
  }

  @override
  List<Object?> get props => [
    status,
    errorMessage,
    successMessage,
    tripId,
    tripApprovedForClient,
    currentTripList,
    tripRequestedListForDriver,
    tripStatus,
    currentTrip,
    tripPrice,
    paymentStatusModel,
    driverLat,
    driverLng,
  ];
}
