import 'realtime_trip_cubit.dart';

extension RealTimeTripStateStatusExtension on RealTimeTripStatus {
  bool get isConnecting => this == RealTimeTripStatus.connecting;
  bool get isConnected => this == RealTimeTripStatus.connected;
  bool get isDisconnected => this == RealTimeTripStatus.disconnected;
  bool get isRequestTripLoading =>
      this == RealTimeTripStatus.requestTripLoading;
  bool get isRequestTripSuccess =>
      this == RealTimeTripStatus.requestTripSuccess;
  bool get isRequestTripFailure =>
      this == RealTimeTripStatus.requestTripFailure;
  bool get isTripApproveLoading =>
      this == RealTimeTripStatus.tripApproveLoading;
  bool get isTripApproveSuccess =>
      this == RealTimeTripStatus.tripApproveSuccess;
  bool get isTripApproveFailure =>
      this == RealTimeTripStatus.tripApproveFailure;
  bool get isRejectTripLoading => this == RealTimeTripStatus.rejectTripLoading;
  bool get isRejectTripSuccess => this == RealTimeTripStatus.rejectTripSuccess;
  bool get isRejectTripFailure => this == RealTimeTripStatus.rejectTripFailure;
  bool get isStartTripLoading => this == RealTimeTripStatus.startTripLoading;
  bool get isStartTripSuccess => this == RealTimeTripStatus.startTripSuccess;
  bool get isStartTripFailure => this == RealTimeTripStatus.startTripFailure;
  bool get isEndTripLoading => this == RealTimeTripStatus.endTripLoading;
  bool get isEndTripSuccess => this == RealTimeTripStatus.endTripSuccess;
  bool get isEndTripFailure => this == RealTimeTripStatus.endTripFailure;
  bool get isCancelTripLoading => this == RealTimeTripStatus.cancelTripLoading;
  bool get isCancelTripSuccess => this == RealTimeTripStatus.cancelTripSuccess;
  bool get isCancelTripFailure => this == RealTimeTripStatus.cancelTripFailure;
  bool get isTripApprovedForClientReceived =>
      this == RealTimeTripStatus.tripApprovedForClientReceived;
  bool get isTripStartedForClientReceived =>
      this == RealTimeTripStatus.tripStartedForClientReceived;
  bool get isTripStartedForDriverReceived =>
      this == RealTimeTripStatus.tripStartedForDriverReceived;
  bool get isTripEndedForClientReceived =>
      this == RealTimeTripStatus.tripEndedForClientReceived;
  bool get isTripEndedForDriverReceived =>
      this == RealTimeTripStatus.tripEndedForDriverReceived;
  bool get isTripCanceledReceived =>
      this == RealTimeTripStatus.tripCanceledReceived;

  bool get isNewRequestedTripsForDriver =>
      this == RealTimeTripStatus.newRequestedTripsForDriver;

  bool get isError => this == RealTimeTripStatus.error;
  bool get isArrivedDriverToClientLoading =>
      this == RealTimeTripStatus.arrivedDriverToClientLoading;
  bool get isArrivedDriverToClientSuccess =>
      this == RealTimeTripStatus.arrivedDriverToClientSuccess;
  bool get isArrivedDriverToClientFailure =>
      this == RealTimeTripStatus.arrivedDriverToClientFailure;
  bool get isDriverArrivedTripReceived =>
      this == RealTimeTripStatus.driverArrivedTripReceived;
  bool get isClientArrivedTripReceived =>
      this == RealTimeTripStatus.clientArrivedTripReceived;
  bool get isCurrentTripReceived =>
      this == RealTimeTripStatus.currentTripReceived;

  bool get isTripPaymentUpdated =>
      this == RealTimeTripStatus.tripPaymentUpdatedReceived;

  bool get isPayTripInCashLoading =>
      this == RealTimeTripStatus.payTripInCashLoading;
  bool get isPayTripInCashSuccess =>
      this == RealTimeTripStatus.payTripInCashSuccess;
  bool get isPayTripInCashFailure =>
      this == RealTimeTripStatus.payTripInCashFailure;
}
