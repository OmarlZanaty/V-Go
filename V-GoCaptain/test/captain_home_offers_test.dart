import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:v_go_captain/core/services/location_service.dart';
import 'package:v_go_captain/core/services/realtime_service.dart';
import 'package:v_go_captain/core/utils/app_constants.dart';
import 'package:v_go_captain/features/finance/data/repo/finance_repo.dart';
import 'package:v_go_captain/features/home/presentation/logic/cubit/captain_home_cubit.dart';
import 'package:v_go_captain/features/trips/data/repo/trip_repo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRealtime realtime;
  late CaptainHomeCubit cubit;

  void offer(String id) => realtime.onTripOffer!({
    'tripId': id,
    'startLocation': {'lat': 30.0, 'lng': 31.0, 'address': 'Pickup'},
    'endLocation': {'lat': 30.1, 'lng': 31.1, 'address': 'Destination'},
    'price': 100,
    'client': {
      'clientId': 'client-$id',
      'fullName': 'Test Rider',
      'phoneNumber': '01000000000',
      'rating': 5,
    },
    'paymentMethod': 'Cash',
  });

  setUp(() {
    realtime = _FakeRealtime();
    cubit = CaptainHomeCubit(
      realtime,
      _FakeLocation(),
      _FakeTripRepo(),
      _FakeFinanceRepo(),
    );
  });
  tearDown(() async => cubit.close());

  test('back-to-back offers retain both trips and the first offer', () {
    offer('first');
    final first = cubit.state.offers.single;
    offer('second');

    expect(cubit.state.offers, hasLength(2));
    expect(cubit.state.offers.map((o) => o.tripId), ['first', 'second']);
    expect(cubit.state.offers.first, same(first));
  });

  test('duplicate trip IDs retain a single offer', () {
    offer('first');
    final first = cubit.state.offers.single;
    offer('first');

    expect(cubit.state.offers, hasLength(1));
    expect(cubit.state.offers.single, same(first));
  });

  test('rejectOffer removes only its offer without calling RejectTrip', () async {
    offer('first');
    offer('second');
    final second = cubit.state.offers.last;

    await cubit.rejectOffer('first');

    expect(cubit.state.offers, [same(second)]);
    expect(realtime.rejected, isEmpty);
  });

  for (final event in ['taken', 'cancelled']) {
    test('trip $event removes only the matching offer', () {
      offer('first');
      offer('second');
      final second = cubit.state.offers.last;
      final callback = event == 'taken'
          ? realtime.onTripTaken!
          : realtime.onTripCancelled!;

      callback('unknown');
      expect(cubit.state.offers, hasLength(2));
      callback('first');

      expect(cubit.state.offers, [same(second)]);
    });
  }

  test('acceptOffer activates the selected offer and clears all offers', () async {
    offer('first');
    offer('second');
    final selected = cubit.state.offers.last;

    await cubit.acceptOffer('second');

    expect(realtime.accepted, ['second']);
    expect(cubit.state.activeTrip, same(selected));
    expect(cubit.state.stage, TripStage.accepted);
    expect(cubit.state.offers, isEmpty);
    expect(cubit.state.isBusy, isFalse);
    expect(cubit.state.error, isNull);
  });

  test('cancelActiveTrip cancels the accepted trip without completion', () async {
    var completions = 0;
    cubit.onTripCompleted = () => completions++;
    offer('first');
    await cubit.acceptOffer('first');
    expect(cubit.state.activeTrip?.tripId, 'first');
    expect(realtime.cancelled, isEmpty);

    await cubit.cancelActiveTrip();

    expect(realtime.cancelled, ['first']);
    expect(cubit.state.activeTrip, isNull);
    expect(cubit.state.isBusy, isFalse);
    expect(cubit.state.error, isNull);
    expect(completions, 0);
  });
}

// Fail on unexpected calls instead of returning null from missing fake methods.
class _Fake {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRealtime extends _Fake implements RealtimeService {
  @override
  void Function(Map<dynamic, dynamic>)? onTripOffer;
  @override
  void Function(String)? onTripTaken;
  @override
  void Function(String)? onTripCancelled;
  @override
  void Function()? onConnectionLost;
  @override
  void Function()? onReconnected;
  @override
  void Function()? onPaymentUpdated;
  @override
  void Function(double, double)? onClientLocation;

  final accepted = <String>[];
  final rejected = <String>[];
  final cancelled = <String>[];

  @override
  Stream<DriverOnlineBlock> get onlineBlockedStream => const Stream.empty();

  @override
  Future<void> acceptTrip({
    required String tripId,
    required double lat,
    required double lng,
  }) async {
    accepted.add(tripId);
  }

  @override
  Future<void> rejectTrip(String tripId) async => rejected.add(tripId);

  @override
  Future<void> cancelAcceptedTrip(String tripId) async => cancelled.add(tripId);

  @override
  Future<void> updateDriverStatus({
    required bool isAvailable,
    double? lat,
    double? lng,
  }) async {}

  @override
  Future<void> disconnect() async {}
}

class _FakeLocation extends _Fake implements LocationService {
  @override
  Future<Position> currentPosition({
    Duration timeLimit = const Duration(seconds: 8),
  }) async => Position(
    latitude: 30,
    longitude: 31,
    timestamp: DateTime.utc(2026),
    accuracy: 1,
    altitude: 0,
    altitudeAccuracy: 1,
    heading: 0,
    headingAccuracy: 1,
    speed: 0,
    speedAccuracy: 1,
  );
}

class _FakeTripRepo extends _Fake implements TripRepo {}

class _FakeFinanceRepo extends _Fake implements FinanceRepo {}
