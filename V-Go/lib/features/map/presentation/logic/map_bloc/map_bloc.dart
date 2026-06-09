// map_bloc.dart
import 'dart:async';
import 'dart:developer';
import 'dart:math' hide log;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';

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
      final suggestions = await mapRepo.getPlaceSuggestions(
        event.query,
        event.sessionToken,
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

  void _onUpdateCurrentLocation(
    UpdateCurrentLocation event,
    Emitter<MapState> emit,
  ) {
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

  Future<void> _onUpdateDriverLocation(
    UpdateDriverLocation event,
    Emitter<MapState> emit,
  ) async {
    // Move the captain marker immediately on every update.
    emit(state.copyWith(driverLocation: event.driverLocation));

    // Recalculate the captain's live route to its target, throttled so we don't
    // spam the Routes API on every GPS tick.
    final target = event.target;
    if (target == null) return;
    final now = DateTime.now();
    if (_lastDriverRouteCalcAt != null &&
        now.difference(_lastDriverRouteCalcAt!) < const Duration(seconds: 4)) {
      return;
    }
    _lastDriverRouteCalcAt = now;
    try {
      final r = await mapRepo.getRoute(event.driverLocation, target);
      if (isClosed) return;
      emit(state.copyWith(routeDriverToPickup: r.points));
    } catch (e) {
      log('driver route calc failed: $e');
    }
  }

  void _onClearDriverLocation(
    ClearDriverLocation event,
    Emitter<MapState> emit,
  ) {
    _lastDriverRouteCalcAt = null;
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
