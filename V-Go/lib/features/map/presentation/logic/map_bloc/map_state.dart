import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../../core/utils/app_constants.dart';
import '../../../../../core/utils/model/location_model.dart';
import '../../../data/model/place_suggestion_model.dart';

class MapState extends Equatable {
  final LocationModel? currentLocation;
  final LocationModel? fromLocation;
  final List<LatLng> routeDriverToPickup;
  final List<LatLng> routePickupToDestination;
  final LocationModel? toLocation;
  final String tripDuration;
  final String driverToClientDuration;
  final String? fromAddress;
  final String? toAddress;
  final String? currentAddress;
  final List<LatLng> routePoints;
  final double? distanceKm;
  final String? error;
  final List<PlaceSuggestionModel> placeSuggestions;
  final bool isFromFieldFocused;
  final MapType mapType;
  final RideStatus rideStatus;
  final bool isCalculatingRoute;
  final Duration? remainingTime;
  final BitmapDescriptor? timeMarkerIcon;
  final List<LocationModel> fakeScooterLocations;
  final bool showFakeScooters;
  // Live captain location during an active trip (null otherwise).
  final LocationModel? driverLocation;
  // What's left of the captain's live route (to the pickup, then to the
  // destination): road meters and estimated seconds. Null until the first
  // captain route is computed; cleared with the driver location.
  final double? driverRemainingMeters;
  final double? driverRemainingSeconds;

  const MapState({
    this.currentLocation,
    this.fromLocation,
    this.toLocation,
    this.fromAddress,
    this.toAddress,
    this.routePoints = const [],
    this.distanceKm,
    this.error,
    this.tripDuration = '',
    this.driverToClientDuration = '',
    this.placeSuggestions = const [],
    this.isFromFieldFocused = true,
    this.mapType = MapType.normal,
    this.routeDriverToPickup = const [],
    this.routePickupToDestination = const [],
    this.rideStatus = RideStatus.accepted,
    this.isCalculatingRoute = false,
    this.currentAddress,
    this.remainingTime,
    this.timeMarkerIcon,
    this.fakeScooterLocations = const [],
    this.showFakeScooters = false,
    this.driverLocation,
    this.driverRemainingMeters,
    this.driverRemainingSeconds,
  });

  MapState copyWith({
    LocationModel? currentLocation,
    LocationModel? fromLocation,
    LocationModel? toLocation,
    String? fromAddress,
    String? toAddress,
    List<LatLng>? routePoints,
    double? distanceKm,
    String? tripDuration,
    String? driverToClientDuration,
    String? error,
    List<PlaceSuggestionModel>? placeSuggestions,
    bool? isFromFieldFocused,
    MapType? mapType,
    List<LatLng>? routeDriverToPickup,
    List<LatLng>? routePickupToDestination,
    RideStatus? rideStatus,
    bool? isCalculatingRoute,
    String? currentAddress,
    Duration? remainingTime,
    BitmapDescriptor? timeMarkerIcon,
    List<LocationModel>? fakeScooterLocations,
    bool? showFakeScooters,
    LocationModel? driverLocation,
    bool clearDriverLocation = false,
    double? driverRemainingMeters,
    double? driverRemainingSeconds,
  }) {
    return MapState(
      currentLocation: currentLocation ?? this.currentLocation,
      fromLocation: fromLocation ?? this.fromLocation,
      toLocation: toLocation ?? this.toLocation,
      fromAddress: fromAddress ?? this.fromAddress,
      toAddress: toAddress ?? this.toAddress,
      routePoints: routePoints ?? this.routePoints,
      distanceKm: distanceKm ?? this.distanceKm,
      tripDuration: tripDuration ?? this.tripDuration,
      driverToClientDuration:
          driverToClientDuration ?? this.driverToClientDuration,
      error: error ?? this.error,
      placeSuggestions: placeSuggestions ?? this.placeSuggestions,
      isFromFieldFocused: isFromFieldFocused ?? this.isFromFieldFocused,
      mapType: mapType ?? this.mapType,
      routeDriverToPickup: routeDriverToPickup ?? this.routeDriverToPickup,
      routePickupToDestination:
          routePickupToDestination ?? this.routePickupToDestination,
      rideStatus: rideStatus ?? this.rideStatus,
      isCalculatingRoute: isCalculatingRoute ?? this.isCalculatingRoute,
      currentAddress: currentAddress ?? this.currentAddress,
      remainingTime: remainingTime ?? this.remainingTime,
      timeMarkerIcon: timeMarkerIcon ?? this.timeMarkerIcon,
      fakeScooterLocations: fakeScooterLocations ?? this.fakeScooterLocations,
      showFakeScooters: showFakeScooters ?? this.showFakeScooters,
      driverLocation:
          clearDriverLocation ? null : (driverLocation ?? this.driverLocation),
      driverRemainingMeters: clearDriverLocation
          ? null
          : (driverRemainingMeters ?? this.driverRemainingMeters),
      driverRemainingSeconds: clearDriverLocation
          ? null
          : (driverRemainingSeconds ?? this.driverRemainingSeconds),
    );
  }

  @override
  List<Object?> get props => [
    currentLocation,
    fromLocation,
    toLocation,
    fromAddress,
    toAddress,
    routePoints,
    distanceKm,
    error,
    placeSuggestions,
    isFromFieldFocused,
    mapType,
    routeDriverToPickup,
    routePickupToDestination,
    rideStatus,
    isCalculatingRoute,
    currentAddress,
    remainingTime,
    fakeScooterLocations,
    showFakeScooters,
    driverLocation,
    driverRemainingMeters,
    driverRemainingSeconds,
  ];
}
