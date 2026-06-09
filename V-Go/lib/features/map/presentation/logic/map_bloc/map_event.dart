import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../../core/utils/model/current_trip_model.dart';
import '../../../../../core/utils/model/location_model.dart';
import '../../../../trips/data/model/new_trip_requested_for_driver_model.dart';
import '../../../../trips/data/model/trip_model.dart';

abstract class MapEvent {}

class LoadInitialLocation extends MapEvent {}

class SearchLocation extends MapEvent {
  final String query;
  final bool isFrom;
  final String sessionToken;

  SearchLocation(
    this.query, {
    required this.isFrom,
    required this.sessionToken,
  });
}

class SelectPlace extends MapEvent {
  final TripLocationModel place;
  final bool isFrom;

  SelectPlace(this.place, {required this.isFrom});
}

class SelectLocationFromMap extends MapEvent {
  final LocationModel location;
  final bool isFrom;

  SelectLocationFromMap({required this.location, required this.isFrom});
}

class CalculateRoute extends MapEvent {
  final LocationModel fromLocation;
  final LocationModel toLocation;

  CalculateRoute({required this.fromLocation, required this.toLocation});
}

class UpdateCurrentLocation extends MapEvent {
  final LocationModel location;

  UpdateCurrentLocation(this.location);
}

class UpdateCurrentLocationError extends MapEvent {
  final String error;

  UpdateCurrentLocationError(this.error);
}

class ToggleFieldFocus extends MapEvent {
  final bool isFrom;

  ToggleFieldFocus({required this.isFrom});
}

class SwitchMapType extends MapEvent {
  final MapType mapType;

  SwitchMapType(this.mapType);
}

class CalculateDriverToPickupRoute extends MapEvent {
  final LocationModel from;
  final LocationModel to;
  CalculateDriverToPickupRoute({required this.from, required this.to});
}

// مسار من العميل للوجهة
class CalculatePickupToDestinationRoute extends MapEvent {
  final LocationModel from;
  final LocationModel to;
  CalculatePickupToDestinationRoute({required this.from, required this.to});
}

class SetTrip extends MapEvent {
  final NewTripRequestedForDriverModel trip;
  SetTrip({required this.trip});
}

class SetTripForClient extends MapEvent {
  final CurrentTripModel trip;
  SetTripForClient({required this.trip});
}

// clear driver to pickup route
class ClearDriverToPickupRoute extends MapEvent {}

// clear pickup to destination route
class ClearPickupToDestinationRoute extends MapEvent {}

class UpdateRemainingTime extends MapEvent {
  final Duration remaining;
  UpdateRemainingTime(this.remaining);
}

class GenerateFakeScooters extends MapEvent {}

class ClearFakeScooters extends MapEvent {}

/// Live captain location pushed from the server during an active trip. [target]
/// is the point the captain is heading to (pickup before the ride starts,
/// destination after) so the bloc can redraw the captain's live route.
class UpdateDriverLocation extends MapEvent {
  final LocationModel driverLocation;
  final LocationModel? target;
  UpdateDriverLocation({required this.driverLocation, this.target});
}

/// Clear the captain marker + live route (trip ended/cancelled).
class ClearDriverLocation extends MapEvent {}
