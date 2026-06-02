import 'dart:developer';

import 'package:signalr_netcore/signalr_client.dart';

import '../config/app_config.dart';
import '../utils/app_constants.dart';

/// Manages the two SignalR connections the Captain app needs:
/// - driverHub: push availability + live location (`UpdateDriverStatus`)
/// - tripHub:   receive trip offers and drive the trip lifecycle
///
/// On connect to tripHub the backend auto-joins the driver to their
/// `Driver_{uid}` group, so offers for this driver arrive automatically.
class RealtimeService {
  HubConnection? _driverHub;
  HubConnection? _tripHub;
  bool _connected = false;
  bool get isConnected => _connected;

  // Callbacks the UI/cubit can listen to.
  void Function(Map<dynamic, dynamic> offer)? onTripOffer;
  void Function(String tripId)? onTripTaken;
  void Function()? onConnectionLost;

  HubConnection _build(String hubPath) {
    return HubConnectionBuilder()
        .withUrl(
          AppConfig.hubUrl(hubPath),
          options: HttpConnectionOptions(
            requestTimeout: 60000,
            accessTokenFactory: () async => AppConstants.kToken,
          ),
        )
        .withAutomaticReconnect()
        .build();
  }

  Future<void> connect() async {
    if (_connected) return;

    _driverHub = _build('driverHub');
    _tripHub = _build('tripHub');

    // Incoming trip offers (two events depending on backend path).
    void offerHandler(List<Object?>? args) {
      final data = (args != null && args.isNotEmpty) ? args.first : null;
      if (data is Map) onTripOffer?.call(data);
    }

    _tripHub!.on('RecievePendingTrips', offerHandler);
    _tripHub!.on('ReceiveNewTrip', offerHandler);
    _tripHub!.on('TripTakenByAnotherDriver', (args) {
      final data = (args != null && args.isNotEmpty) ? args.first : null;
      final id = (data is Map ? (data['tripId'] ?? data['TripId']) : data)
          ?.toString();
      if (id != null) onTripTaken?.call(id);
    });

    for (final hub in [_driverHub!, _tripHub!]) {
      hub.onclose(({error}) {
        _connected = false;
        log('Hub closed: $error', name: 'RealtimeService');
        onConnectionLost?.call();
      });
    }

    await _driverHub!.start();
    await _tripHub!.start();
    _connected = true;
    log('Connected to driverHub + tripHub', name: 'RealtimeService');
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
    try {
      await _driverHub?.stop();
      await _tripHub?.stop();
    } finally {
      _connected = false;
    }
  }
}
