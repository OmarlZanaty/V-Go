// map_bloc.dart
import 'dart:async';
import 'dart:developer';
import 'dart:math' hide log;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../../core/helpers/geo_utils.dart';
import '../../../../../core/utils/app_constants.dart';
import '../../../../../core/utils/model/location_model.dart';
import '../../../data/repo/map_repo.dart';
import 'map_event.dart';
import 'map_state.dart';

class MapBloc extends Bloc<MapEvent, MapState> {
  final MapRepo mapRepo;
  StreamSubscription<LocationModel>? _locationSubscription;

  // simple throttle to avoid spamming Routes API
  DateTime? _lastRouteCalcAt;
  final Duration _minRouteInterval = const Duration(seconds: 3);

  // Ensures we kick off the background location load (for closest-first search)
  // at most once, instead of awaiting GPS on every keystroke (which froze search).
  bool _searchOriginRequested = false;

  // The pickup starts as the first GPS fix, which is often coarse (indoors,
  // cold GPS) and can be ~100 m off. Until the rider chooses a pickup
  // themselves, keep it following the refined GPS so the captain is sent to
  // where the rider really is.
  bool _pickupFollowsGps = false;
  LocationModel? _pickupGeocodedAt;

  /// Moves smaller than this don't shift the pickup (avoids route/price churn).
  static const double _pickupRefineMeters = 15;

  MapBloc({required this.mapRepo}) : super(const MapState()) {
    on<LoadInitialLocation>(_onLoadInitialLocation);
    on<SearchLocation>(
      _onSearchLocation,
      transformer: (events, mapper) => events
          .debounceTime(const Duration(milliseconds: 350))
          .asyncExpand(mapper),
    );
    on<SelectPlace>(_onSelectPlace);
    on<SelectLocationFromMap>(_onSelectLocationFromMap);
    on<CalculateRoute>(_onCalculateRoute);
    on<UpdateCurrentLocation>(_onUpdateCurrentLocation);
    on<UpdateCurrentLocationError>(_onUpdateCurrentLocationError);
    on<ToggleFieldFocus>(_onToggleFieldFocus);
    on<SwitchMapType>(_onSwitchMapType);
    on<CalculateDriverToPickupRoute>(_onCalculateDriverToPickupRoute);
    on<CalculatePickupToDestinationRoute>(_onCalculatePickupToDestinationRoute);
    on<SetTrip>(_onSetTrip);
    on<ClearDriverToPickupRoute>(_onClearDriverToPickupRoute);
    on<ClearPickupToDestinationRoute>(_onClearPickupToDestinationRoute);
    on<SetTripForClient>(_onSetTripForClient);
    on<UpdateRemainingTime>((event, emit) {
      log(
        '🔁 UpdateRemainingTime event received: ${event.remaining.inMinutes} min',
      );
      emit(state.copyWith(remainingTime: event.remaining));
    });
    on<GenerateFakeScooters>(_onGenerateFakeScooters);
    on<ClearFakeScooters>(_onClearFakeScooters);
    on<UpdateDriverLocation>(_onUpdateDriverLocation);
    on<ClearDriverLocation>(_onClearDriverLocation);

    _locationSubscription = mapRepo.getLocationStream().listen(
      (location) {
        // Filter out inaccurate updates to prevent jumping (accuracy > 100m)
        if (location.accuracy != null && location.accuracy! > 100) {
          log('Ignoring inaccurate location update: ${location.accuracy}m');
          return;
        }
        add(UpdateCurrentLocation(location));
      },
      onError: (error) {
        add(UpdateCurrentLocationError(error.toString()));
      },
    );
  }

  // --- initial load ---
  Future<void> _onLoadInitialLocation(
    LoadInitialLocation event,
    Emitter<MapState> emit,
  ) async {
    try {
      final location = await mapRepo.getCurrentLocation();
      final address = await mapRepo.getAddressFromCoordinates(
        location.latitude,
        location.longitude,
      );

      emit(
        state.copyWith(
          currentLocation: location,
          currentAddress: address,
          fromLocation: location,
          fromAddress: address,
        ),
      );
      _pickupFollowsGps = true;
      _pickupGeocodedAt = location;
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onSearchLocation(
    SearchLocation event,
    Emitter<MapState> emit,
  ) async {
    try {
      if (event.query.isEmpty) {
        emit(state.copyWith(placeSuggestions: []));
        return;
      }
      // Sort results by distance so the nearest places appear first, using the
      // current location (fall back to the chosen pickup point). NEVER await GPS
      // here — SearchLocation runs sequentially (asyncExpand), so a slow GPS call
      // freezes autocomplete. If we have no origin yet, kick off the location load
      // ONCE in the background (concurrent event) so later keystrokes can sort.
      final origin = state.currentLocation ?? state.fromLocation;
      if (origin == null && !_searchOriginRequested) {
        _searchOriginRequested = true;
        add(LoadInitialLocation());
      }
      final suggestions = await mapRepo.getPlaceSuggestions(
        event.query,
        event.sessionToken,
        originLat: origin?.latitude,
        originLng: origin?.longitude,
      );
      emit(state.copyWith(placeSuggestions: suggestions));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onSelectPlace(SelectPlace event, Emitter<MapState> emit) async {
    try {
      if (event.isFrom) {
        _pickupFollowsGps = false;
        emit(
          state.copyWith(
            fromLocation: LocationModel(
              latitude: event.place.lat,
              longitude: event.place.lng,
            ),
            fromAddress: event.place.address,
            placeSuggestions: [],
          ),
        );
      } else {
        emit(
          state.copyWith(
            toLocation: LocationModel(
              latitude: event.place.lat,
              longitude: event.place.lng,
            ),
            toAddress: event.place.address,
            placeSuggestions: [],
          ),
        );
      }
      if (state.fromLocation != null && state.toLocation != null) {
        await _maybeCalculateRoutes(emit);
      }
      log("FROM: ${state.fromAddress} | TO: ${state.toAddress}");
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onSelectLocationFromMap(
    SelectLocationFromMap event,
    Emitter<MapState> emit,
  ) async {
    try {
      final address = await mapRepo.getAddressFromCoordinates(
        event.location.latitude,
        event.location.longitude,
      );
      if (event.isFrom) {
        // "Use my location" passes the live GPS fix itself — keep following
        // it; a point the rider chose on the map is final.
        _pickupFollowsGps = identical(event.location, state.currentLocation);
        _pickupGeocodedAt = event.location;
        emit(
          state.copyWith(
            fromLocation: event.location,
            fromAddress: address,
            placeSuggestions: [],
          ),
        );
      } else {
        emit(
          state.copyWith(
            toLocation: event.location,
            toAddress: address,
            placeSuggestions: [],
          ),
        );
      }
      if (state.fromLocation != null && state.toLocation != null) {
        log("FROM: ${state.fromAddress} | TO: ${state.toAddress}");
        await _maybeCalculateRoutes(emit);
      }
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onCalculateRoute(
    CalculateRoute event,
    Emitter<MapState> emit,
  ) async {
    try {
      final routeResult = await mapRepo.getRoute(
        event.fromLocation,
        event.toLocation,
      );

      emit(
        state.copyWith(
          routePoints: routeResult.points,
          distanceKm: routeResult.distanceKm,
          tripDuration: routeResult.duration,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onUpdateCurrentLocation(
    UpdateCurrentLocation event,
    Emitter<MapState> emit,
  ) async {
    List<LocationModel> fakeLocations = state.fakeScooterLocations;

    // If we are supposed to show fake scooters but haven't generated them yet (e.g. location was null)
    if (state.showFakeScooters && state.fakeScooterLocations.isEmpty) {
      fakeLocations = _generateFakeScootersList(event.location);
    }

    emit(
      state.copyWith(
        currentLocation: event.location,
        fakeScooterLocations: fakeLocations,
      ),
    );

    await _refinePickup(event.location, emit);
  }

  /// Move an auto (GPS) pickup to a newer, better fix. See [_pickupFollowsGps].
  Future<void> _refinePickup(
    LocationModel fix,
    Emitter<MapState> emit,
  ) async {
    final from = state.fromLocation;
    if (!_pickupFollowsGps || from == null) return;
    final moved = GeoUtils.haversine(
      LatLng(from.latitude, from.longitude),
      LatLng(fix.latitude, fix.longitude),
    );
    if (moved < _pickupRefineMeters) return;

    emit(state.copyWith(fromLocation: fix));
    if (state.toLocation != null) await _maybeCalculateRoutes(emit);

    // Re-geocode only after a real move, not for every refinement.
    final last = _pickupGeocodedAt;
    if (last != null &&
        GeoUtils.haversine(
              LatLng(last.latitude, last.longitude),
              LatLng(fix.latitude, fix.longitude),
            ) <
            50) {
      return;
    }
    _pickupGeocodedAt = fix;
    try {
      final address = await mapRepo.getAddressFromCoordinates(
        fix.latitude,
        fix.longitude,
      );
      // Still the same auto pickup (the rider didn't pick one meanwhile)?
      if (isClosed || !_pickupFollowsGps || state.fromLocation != fix) return;
      emit(state.copyWith(fromAddress: address));
    } catch (_) {}
  }

  void _onUpdateCurrentLocationError(
    UpdateCurrentLocationError event,
    Emitter<MapState> emit,
  ) {
    emit(state.copyWith(error: event.error));
  }

  // ... (existing handlers)

  void _onGenerateFakeScooters(
    GenerateFakeScooters event,
    Emitter<MapState> emit,
  ) {
    List<LocationModel> fakeLocations = state.fakeScooterLocations;

    if (state.currentLocation != null && state.fakeScooterLocations.isEmpty) {
      fakeLocations = _generateFakeScootersList(state.currentLocation!);
    }

    emit(
      state.copyWith(
        showFakeScooters: true,
        fakeScooterLocations: fakeLocations,
      ),
    );
  }

  void _onClearFakeScooters(ClearFakeScooters event, Emitter<MapState> emit) {
    emit(state.copyWith(showFakeScooters: false, fakeScooterLocations: []));
  }

  // --- live captain tracking ---
  DateTime? _lastDriverRouteCalcAt;
  // The point the captain was last routed to. When it changes (pickup → drop-off
  // the moment the ride starts) we bypass the throttle and recompute right away,
  // so the live line flips to the destination instantly instead of lingering on
  // the old captain→pickup route for up to a few seconds.
  LocationModel? _lastDriverTarget;

  Future<void> _onUpdateDriverLocation(
    UpdateDriverLocation event,
    Emitter<MapState> emit,
  ) async {
    final target = event.target;
    final driver = LatLng(
      event.driverLocation.latitude,
      event.driverLocation.longitude,
    );
    final targetChanged =
        target != null &&
        (_lastDriverTarget == null ||
            _lastDriverTarget!.latitude != target.latitude ||
            _lastDriverTarget!.longitude != target.longitude);

    // While the captain is still on the route we already have, just cut the
    // driven part off: the line stays put and the scooter moves along it,
    // with no Routes API call per GPS tick. Only the part still ahead is
    // searched (plus a couple of vertices of jitter): matching against the
    // whole line let a captain who turned back or took a nearby street keep
    // "fitting" the old route, so it was never recalculated.
    final snap = GeoUtils.snapToPath(
      driver,
      _driverRouteFull,
      from: max(0, _driverSegment - 2),
    );
    if (!targetChanged && snap != null && snap.distance <= 30) {
      _driverSegment = snap.segment;
      _driverOffRouteCount = 0;
      final ahead = [snap.point, ..._driverRouteFull.skip(snap.segment + 1)];
      final meters = _pathMeters(ahead);
      emit(
        state.copyWith(
          driverLocation: event.driverLocation,
          routeDriverToPickup: ahead,
          driverRemainingMeters: meters,
          driverRemainingSeconds: _secondsFor(meters),
        ),
      );
      return;
    }

    // Move the captain marker immediately on every update.
    emit(state.copyWith(driverLocation: event.driverLocation));

    // New target, or the captain left the line: fetch a fresh route. Needs
    // two off-route updates in a row (one GPS jump shouldn't redraw), and is
    // throttled so a captain driving off-route doesn't spam the API — except
    // the first calc after the target changes, which must run immediately.
    if (target == null) return;
    if (!targetChanged && _driverRouteFull.isNotEmpty) {
      _driverOffRouteCount++;
      if (_driverOffRouteCount < 2) return;
    }
    final now = DateTime.now();
    if (!targetChanged &&
        (_driverRouteInFlight ||
            (_lastDriverRouteCalcAt != null &&
                now.difference(_lastDriverRouteCalcAt!) <
                    const Duration(seconds: 3)))) {
      return;
    }
    _lastDriverRouteCalcAt = now;
    _lastDriverTarget = target;
    _driverRouteInFlight = true;
    try {
      final r = await mapRepo.getRoute(event.driverLocation, target);
      if (isClosed) return;
      // The target moved on (ride started) while this was in flight — a newer
      // request owns the line now.
      final current = _lastDriverTarget;
      if (current == null ||
          current.latitude != target.latitude ||
          current.longitude != target.longitude) {
        return;
      }
      _driverRouteFull = r.points;
      _driverSegment = 0;
      _driverOffRouteCount = 0;
      _driverRouteMeters = r.distanceKm * 1000;
      _driverRouteSeconds = r.durationSeconds;
      emit(
        state.copyWith(
          routeDriverToPickup: r.points,
          driverRemainingMeters: _driverRouteMeters,
          driverRemainingSeconds: _driverRouteSeconds,
        ),
      );
    } catch (e) {
      log('driver route calc failed: $e');
    } finally {
      _driverRouteInFlight = false;
    }
  }

  // Progress along [_driverRouteFull] and off-route bookkeeping.
  int _driverSegment = 0;
  int _driverOffRouteCount = 0;
  bool _driverRouteInFlight = false;

  // Full captain route from the last Routes API call; the state holds only the
  // part still ahead of the captain.
  List<LatLng> _driverRouteFull = const [];
  // Google's length/duration for that full route, used to pro-rate the ETA as
  // the captain eats into it (no API call per GPS tick).
  double _driverRouteMeters = 0;
  double _driverRouteSeconds = 0;

  static double _pathMeters(List<LatLng> path) {
    var total = 0.0;
    for (var i = 0; i < path.length - 1; i++) {
      total += GeoUtils.haversine(path[i], path[i + 1]);
    }
    return total;
  }

  double? _secondsFor(double meters) {
    if (_driverRouteMeters <= 0 || _driverRouteSeconds <= 0) return null;
    return _driverRouteSeconds * (meters / _driverRouteMeters);
  }

  void _onClearDriverLocation(
    ClearDriverLocation event,
    Emitter<MapState> emit,
  ) {
    _lastDriverRouteCalcAt = null;
    _lastDriverTarget = null;
    _driverRouteFull = const [];
    _driverRouteMeters = 0;
    _driverRouteSeconds = 0;
    _driverSegment = 0;
    _driverOffRouteCount = 0;
    emit(state.copyWith(clearDriverLocation: true, routeDriverToPickup: []));
  }

  List<LocationModel> _generateFakeScootersList(LocationModel center) {
    final random = Random();
    final List<LocationModel> fakeLocations = [];
    final count = 3 + random.nextInt(3);

    for (int i = 0; i < count; i++) {
      fakeLocations.add(_generateRandomLocation(center, 1.0));
    }
    return fakeLocations;
  }

  void _onToggleFieldFocus(ToggleFieldFocus event, Emitter<MapState> emit) {
    emit(state.copyWith(isFromFieldFocused: event.isFrom));
  }

  void _onSwitchMapType(SwitchMapType event, Emitter<MapState> emit) {
    emit(state.copyWith(mapType: event.mapType));
  }

  // explicit driver->pickup route event (if you want manual control)
  Future<void> _onCalculateDriverToPickupRoute(
    CalculateDriverToPickupRoute event,
    Emitter<MapState> emit,
  ) async {
    try {
      emit(state.copyWith(isCalculatingRoute: true));
      final routeResult = await mapRepo.getRoute(event.from, event.to);
      emit(
        state.copyWith(
          routeDriverToPickup: routeResult.points,
          isCalculatingRoute: false,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(error: e.toString(), isCalculatingRoute: false));
    }
  }

  // explicit pickup->destination route event (if you want manual control)
  Future<void> _onCalculatePickupToDestinationRoute(
    CalculatePickupToDestinationRoute event,
    Emitter<MapState> emit,
  ) async {
    try {
      emit(state.copyWith(isCalculatingRoute: true));
      final routeResult = await mapRepo.getRoute(event.from, event.to);
      emit(
        state.copyWith(
          routePickupToDestination: routeResult.points,
          isCalculatingRoute: false,
          tripDuration: routeResult.duration,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(error: e.toString(), isCalculatingRoute: false));
    }
  }

  // decide which routes to calculate automatically
  Future<void> _maybeCalculateRoutes(Emitter<MapState> emit) async {
    // throttle
    final now = DateTime.now();
    if (_lastRouteCalcAt != null &&
        now.difference(_lastRouteCalcAt!) < _minRouteInterval) {
      return;
    }
    _lastRouteCalcAt = now;

    final current = state.currentLocation;
    final from = state.fromLocation;
    final to = state.toLocation;

    // prefer to calculate both if possible
    try {
      if (current != null && from != null && current != from) {
        // calculate driver -> pickup
        final r1 = await mapRepo.getRoute(current, from);
        emit(
          state.copyWith(
            routeDriverToPickup: r1.points,
            distanceKm: r1.distanceKm,
          ),
        );
      }

      final startPoint = from ?? current;
      if (startPoint != null && to != null) {
        // calculate pickup -> destination
        final r2 = await mapRepo.getRoute(startPoint, to);
        emit(
          state.copyWith(
            routePickupToDestination: r2.points,
            routePoints: r2.points,
            distanceKm: r2.distanceKm,
            tripDuration: r2.duration,
          ),
        );
      }
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onSetTrip(SetTrip event, Emitter<MapState> emit) async {
    _pickupFollowsGps = false;
    emit(
      state.copyWith(
        toAddress: event.trip.endLocation.address,
        fromAddress: event.trip.startLocation.address,
        toLocation: LocationModel(
          latitude: event.trip.endLocation.lat,
          longitude: event.trip.endLocation.lng,
        ),
        fromLocation: LocationModel(
          latitude: event.trip.startLocation.lat,
          longitude: event.trip.startLocation.lng,
        ),
      ),
    );
  }

  Future<void> _onSetTripForClient(
    SetTripForClient event,
    Emitter<MapState> emit,
  ) async {
    log(event.trip.tripStatus.toString());
    // The trip exists: its pickup is fixed on the server now.
    _pickupFollowsGps = false;

    // تحويل الحالة بأمان مع orElse
    final status = RideStatus.values.firstWhere(
      (e) => e.name == event.trip.tripStatus,
      orElse: () => RideStatus.accepted,
    );

    final fromLoc = LocationModel(
      latitude: event.trip.from.lat,
      longitude: event.trip.from.lng,
    );
    final toLoc = LocationModel(
      latitude: event.trip.to.lat,
      longitude: event.trip.to.lng,
    );

    // حدث واحد لتحديث كل الحقول الضرورية
    emit(
      state.copyWith(
        rideStatus: status,
        toAddress: event.trip.to.address,
        fromAddress: event.trip.from.address,
        toLocation: toLoc,
        fromLocation: fromLoc,
      ),
    );

    // احسب المسار فورًا داخل الـ handler (يمنع السباقات ويضمن النتائج)
    try {
      emit(state.copyWith(isCalculatingRoute: true));
      final routeResult = await mapRepo.getRoute(fromLoc, toLoc);
      emit(
        state.copyWith(
          routePoints: routeResult.points,
          distanceKm: routeResult.distanceKm,
          isCalculatingRoute: false,
        ),
      );
    } catch (e) {
      log('calculate route failed in _onSetTripForClient: $e');
      emit(state.copyWith(error: e.toString(), isCalculatingRoute: false));
    }
  }

  FutureOr<void> _onClearDriverToPickupRoute(
    ClearDriverToPickupRoute event,
    Emitter<MapState> emit,
  ) {
    _driverRouteFull = const [];
    emit(state.copyWith(routeDriverToPickup: []));
  }

  FutureOr<void> _onClearPickupToDestinationRoute(
    ClearPickupToDestinationRoute event,
    Emitter<MapState> emit,
  ) {
    emit(state.copyWith(routePickupToDestination: []));
  }

  // --- ETA tracking ---
  Timer? _etaUpdateTimer;
  Timer? _realtimeApiTimer;
  DateTime? _estimatedArrivalTime;

  void startEtaTracking(LocationModel destination) {
    _etaUpdateTimer?.cancel();
    _realtimeApiTimer?.cancel();

    _updateEtaFromServer(destination); // أول تحديث فعلي من Google

    _startRealtimeEta(destination); // بعد كده نحسب يدوي ونحدث كل 3 دقائق
  }

  void _startRealtimeEta(LocationModel destination) {
    log('start ETA tracking');
    // تحديث يدوي كل ثانية
    _etaUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      log('ETA timer tick every second');
      if (_estimatedArrivalTime != null) {
        final remaining = _estimatedArrivalTime!.difference(DateTime.now());
        if (remaining.inSeconds <= 0) {
          _etaUpdateTimer?.cancel();
          // اختياري: إضافة حدث لإيقاف تتبع ETA إذا وصل الوقت لصفر
          return;
        }
        if (isClosed) return;
        // ✅ التأكد من إرسال الـ Duration الكاملة (بما فيها الثواني)
        add(UpdateRemainingTime(remaining));
      }
    });

    // تحديث فعلي من السيرفر كل 3 دقائق
    _realtimeApiTimer = Timer.periodic(const Duration(minutes: 3), (_) async {
      await _updateEtaFromServer(destination);
    });
  }

  int? _lastDistanceMeters;
  Future<void> _updateEtaFromServer(LocationModel destination) async {
    log('update ETA from server');

    try {
      final current = state.currentLocation;
      if (current == null) {
        log('ETA update skipped: current location is null');
        return;
      }

      // نخد الـ ETA + distance من السيرفر
      final result = await mapRepo.getEstimatedTimeOfArrivalWithDistance(
        current,
        destination,
      );

      if (result == null) {
        log('ETA update skipped: API returned NULL');
        return;
      }

      final Duration newEta = result.eta;
      final int distanceMeters = result.distanceMeters;

      // لأول مرة → خزّن المسافة وحدث ETA
      if (_lastDistanceMeters == null) {
        _lastDistanceMeters = distanceMeters;
        _applyNewEta(newEta);
        return;
      }

      //  لو المسافة ثابتة أو أكبر → العربية محركةش → تجاهل التحديث
      if (distanceMeters >= _lastDistanceMeters!) {
        log(" IGNORE ETA UPDATE → vehicle not moving");
        return;
      }

      // العربية اتحركت فعلاً → حدث
      log(" Vehicle moved: $_lastDistanceMeters → $distanceMeters");
      _lastDistanceMeters = distanceMeters;
      _applyNewEta(newEta);
    } catch (e, st) {
      log('update ETA from server failed: $e\n$st');
    }
  }

  void _applyNewEta(Duration eta) {
    _estimatedArrivalTime = DateTime.now().add(eta);
    add(UpdateRemainingTime(eta));
    log("ETA applied: ${eta.inMinutes} min");
  }

  stopEtaTracking() {
    log('stop ETA tracking');
    _etaUpdateTimer?.cancel();
    _realtimeApiTimer?.cancel();
    _etaUpdateTimer = null;
    _realtimeApiTimer = null;
    _estimatedArrivalTime = null;
  }

  @override
  Future<void> close() async {
    await _locationSubscription?.cancel();
    return super.close();
  }

  LocationModel _generateRandomLocation(
    LocationModel center,
    double radiusInKm,
  ) {
    final random = Random();
    // Convert radius from km to degrees (approximate)
    // 1 degree latitude ~= 111 km
    final double radiusInDegrees = radiusInKm / 111.0;

    final double u = random.nextDouble();
    final double v = random.nextDouble();
    final double w = radiusInDegrees * sqrt(u);
    final double t = 2 * pi * v;
    final double x = w * cos(t);
    final double y = w * sin(t);

    // Adjust the x-coordinate for the shrinking of the east-west distances
    final double newX = x / cos(center.latitude * pi / 180);

    final double foundLatitude = center.latitude + y;
    final double foundLongitude = center.longitude + newX;

    return LocationModel(latitude: foundLatitude, longitude: foundLongitude);
  }
}
