import 'dart:developer';

import 'package:signalr_netcore/signalr_client.dart';

import '../cache/cache_helper.dart';
import '../config/app_config.dart';
import '../utils/app_constants.dart';

/// Manages the two SignalR connections the Captain app needs:
/// - driverHub: push availability + live location (`UpdateDriverStatus`)
/// - tripHub:   receive trip offers and drive the trip lifecycle
class RealtimeService {
  HubConnection? _driverHub;
  HubConnection? _tripHub;
  bool _connected = false;
  bool _connecting = false;
  bool get isConnected => _connected;

  // Callbacks the UI/cubit can listen to.
  void Function(Map<dynamic, dynamic> offer)? onTripOffer;
  void Function(String tripId)? onTripTaken;
  void Function()? onConnectionLost;
  void Function()? onReconnected;

  HubConnection _build(String hubPath) {
    return HubConnectionBuilder()
        .withUrl(
          AppConfig.hubUrl(hubPath),
          options: HttpConnectionOptions(
            requestTimeout: 60000,
            // Read the cached token so reconnects always use the freshest one
            // (Dio refresh updates the cache).
            accessTokenFactory: () async {
              final cached =
                  await CacheHelper.getSecuredString(AppConstants.token);
              return cached.isNotEmpty ? cached : AppConstants.kToken;
            },
          ),
        )
        .withAutomaticReconnect()
        .build();
  }

  Future<void> connect() async {
    if (_connected || _connecting) return;
    _connecting = true;
    try {
      final driverHub = _build('driverHub');
      final tripHub = _build('tripHub');
      // Assign before start() so a failed start is cleaned up by the catch below.
      _driverHub = driverHub;
      _tripHub = tripHub;

      void offerHandler(List<Object?>? args) {
        final data = (args != null && args.isNotEmpty) ? args.first : null;
        if (data is Map) onTripOffer?.call(data);
      }

      tripHub.on('RecievePendingTrips', offerHandler);
      tripHub.on('ReceiveNewTrip', offerHandler);
      tripHub.on('TripTakenByAnotherDriver', (args) {
        final data = (args != null && args.isNotEmpty) ? args.first : null;
        final id = (data is Map ? (data['tripId'] ?? data['TripId']) : data)
            ?.toString();
        if (id != null) onTripTaken?.call(id);
      });

      for (final hub in [driverHub, tripHub]) {
        hub.onclose(({error}) {
          _connected = false;
          log('Hub closed: $error', name: 'RealtimeService');
          onConnectionLost?.call();
        });
        hub.onreconnecting(({error}) {
          _connected = false;
          onConnectionLost?.call();
        });
        hub.onreconnected(({connectionId}) {
          _connected = true;
          log('Hub reconnected', name: 'RealtimeService');
          onReconnected?.call();
        });
      }

      await driverHub.start();
      await tripHub.start();
      _connected = true;
      log('Connected to driverHub + tripHub', name: 'RealtimeService');
    } catch (e) {
      // Clean up any partially-started connection so we never leak a zombie.
      await _stopQuietly(_driverHub);
      await _stopQuietly(_tripHub);
      _driverHub = null;
      _tripHub = null;
      _connected = false;
      rethrow;
    } finally {
      _connecting = false;
    }
  }

  Future<void> updateDriverStatus({
    required bool isAvailable,
    double? lat,
    double? lng,
  }) async {
    if (_driverHub?.state != HubConnectionState.Connected) return;
    await _driverHub!.invoke('UpdateDriverStatus', args: [
      {
        'driverId': AppConstants.kUserId,
        'isAvailable': isAvailable,
        'latitude': lat,
        'longitude': lng,
      }
    ]);
  }

  Future<void> acceptTrip({
    required String tripId,
    required double lat,
    required double lng,
  }) async {
    await _tripHub?.invoke('ApproveAndAssignDriverToTrip', args: [
      tripId,
      AppConstants.kUserId,
      lat.toString(),
      lng.toString(),
    ]);
  }

  Future<void> rejectTrip(String tripId) async {
    await _tripHub?.invoke('RejectTrip', args: [tripId]);
  }

  Future<void> arrived(String tripId) async {
    await _tripHub?.invoke('Arrived', args: [tripId, AppConstants.kUserId]);
  }

  Future<void> startTrip(String tripId) async {
    await _tripHub?.invoke('StartTrip', args: [tripId, AppConstants.kUserId]);
  }

  Future<void> endTrip(String tripId) async {
    await _tripHub?.invoke('EndTrip', args: [tripId, AppConstants.kUserId]);
  }

  Future<void> disconnect() async {
    await _stopQuietly(_driverHub);
    await _stopQuietly(_tripHub);
    _driverHub = null;
    _tripHub = null;
    _connected = false;
  }

  Future<void> _stopQuietly(HubConnection? hub) async {
    try {
      await hub?.stop();
    } catch (_) {}
  }
}
