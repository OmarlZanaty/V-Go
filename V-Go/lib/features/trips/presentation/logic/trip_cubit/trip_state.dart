part of 'trip_cubit.dart';

enum TripStatus {
  initial,
  changeKiloPriceSuccess,
  changeKiloPriceFailure,
  changeKiloPriceLoading,
  fareQuoteSuccess,
  fareQuoteFailure,
  fareQuoteLoading,
  getAllTripsSuccess,
  getAllTripsFailure,
  getAllTripsLoading,
  changeDriverCommissionSuccess,
  changeDriverCommissionFailure,
  changeDriverCommissionLoading,
}

extension TripStatusExtension on TripStatus {
  bool get isInitial => this == TripStatus.initial;
  bool get isChangeKiloPriceSuccess =>
      this == TripStatus.changeKiloPriceSuccess;
  bool get isChangeKiloPriceFailure =>
      this == TripStatus.changeKiloPriceFailure;
  bool get isChangeKiloPriceLoading =>
      this == TripStatus.changeKiloPriceLoading;
  bool get isFareQuoteSuccess => this == TripStatus.fareQuoteSuccess;
  bool get isFareQuoteFailure => this == TripStatus.fareQuoteFailure;
  bool get isFareQuoteLoading => this == TripStatus.fareQuoteLoading;
  bool get isGetAllTripsSuccess => this == TripStatus.getAllTripsSuccess;
  bool get isGetAllTripsFailure => this == TripStatus.getAllTripsFailure;
  bool get isGetAllTripsLoading => this == TripStatus.getAllTripsLoading;
  bool get isChangeDriverCommissionSuccess =>
      this == TripStatus.changeDriverCommissionSuccess;
  bool get isChangeDriverCommissionFailure =>
      this == TripStatus.changeDriverCommissionFailure;
  bool get isChangeDriverCommissionLoading =>
      this == TripStatus.changeDriverCommissionLoading;
}

class TripState extends Equatable {
  final TripStatus status;
  final String errorMessage;
  final String successMessage;
  final List<TripModel> trips;
  final List<CurrentTripModel> currentTrips;
  final bool hasNextPage;
  final List<TripModel> filteredTrips;

  /// Server-quoted fare for the route in [quoteKey].
  final double tripPrice;
  final String quoteKey;
  final FareQuoteModel? fareQuote;

  const TripState({
    this.status = TripStatus.initial,
    this.errorMessage = '',
    this.successMessage = '',
    this.trips = const [],
    this.filteredTrips = const [],
    this.currentTrips = const [],
    this.hasNextPage = true,
    this.tripPrice = 0.0,
    this.quoteKey = '',
    this.fareQuote,
  });

  TripState copyWith({
    TripStatus? status,
    String? errorMessage,
    String? successMessage,
    List<TripModel>? trips,
    List<TripModel>? filteredTrips,
    List<CurrentTripModel>? currentTrips,
    bool? hasNextPage,
    double? tripPrice,
    String? quoteKey,
    FareQuoteModel? fareQuote,
    TripModel? trip,
  }) {
    return TripState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      successMessage: successMessage ?? this.successMessage,
      trips: trips ?? this.trips,
      currentTrips: currentTrips ?? this.currentTrips,
      filteredTrips: filteredTrips ?? this.filteredTrips,
      tripPrice: tripPrice ?? this.tripPrice,
      quoteKey: quoteKey ?? this.quoteKey,
      fareQuote: fareQuote ?? this.fareQuote,
      hasNextPage: hasNextPage ?? this.hasNextPage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    errorMessage,
    trips,
    currentTrips,
    filteredTrips,
    successMessage,
    hasNextPage,
    tripPrice,
    quoteKey,
    fareQuote,
  ];
}
