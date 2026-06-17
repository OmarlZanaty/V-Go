import 'dart:developer';

import 'package:signalr_netcore/signalr_client.dart';

import '../../features/trips/data/model/trip_request_model.dart';
import '../config/app_config.dart';
import '../utils/app_constants.dart';

class TripService {
  late final HubConnection _hubConnection;
  bool _isConnected = false;

  // Listeners
  Function(List<Object?>?)? tripApprovedForClient;
  Function(List<Object?>?)? newTripRequestedForDriver;
  Function(List<Object?>?)? tripStartedForClient;
  Function(List<Object?>?)? tripStartedForDriver;
  Function(List<Object?>?)? tripEndedForClient;
  Function(List<Object?>?)? tripEndedForDriver;
  Function(List<Object?>?)? clientArrivedTrip;
  Function(List<Object?>?)? driverArrivedTrip;
  Function(List<Object?>?)? tripCanceledByClient;
  Function(List<Object?>?)? tripCanceledForClient;
  Function(List<Object?>?)? tripCanceledForTripDriver;
  Function(List<Object?>?)? receivePendingTrips;
  Function(List<Object?>?)? receiveCurrentTrip;
  Function(List<Object?>?)? receiveDriverLocation;
  Function(List<Object?>?)? tripTakenByAnotherDriver;
  Function(List<Object?>?)? tripPaymentUpdated;

  /// Fired after the socket transparently reconnects, so callers can re-sync the
  /// current trip (SignalR never replays messages missed while disconnected).
  void Function()? onReconnected;

  TripService() {
    _initializeHubConnection();
  }

  void _initializeHubConnection() {
    _hubConnection = HubConnectionBuilder()
        .withUrl(
          AppConfig.hubUrl('tripHub'),
          options: HttpConnectionOptions(
            requestTimeout: 60000,
            accessTokenFactory: () async => AppConstants.kToken,
          ),
        )
        .withAutomaticReconnect()
        .build();

    _initListeners();

    _hubConnection.onclose(({error}) {
      _isConnected = false;
      log(
        'TripHub connection closed: ${error?.toString()}',
        name: 'TripService',
      );
    });

    _hubConnection.onreconnected(({connectionId}) {
      _isConnected = true;
      log('TripHub reconnected: $connectionId', name: 'TripService');
      // Pull the authoritative current trip — any events sent while we were
      // disconnected are gone, so this is how the UI recovers from "searching".
      onReconnected?.call();
    });
  }

  void _initListeners() {
    //! TripApproved Listeners
    _hubConnection.on('TripApprovedForClient', (args) {
      tripApprovedForClient?.call(args);
      log('TripApproved received in Client: $args', name: 'TripService');
    });

    //! receivePendingTrips Listeners
    _hubConnection.on('RecievePendingTrips', (args) {
      receivePendingTrips?.call(args);
      log('PendingTrips received in Driver: $args', name: 'TripService');
    });

    //! live driver location during a trip
    _hubConnection.on('ReceiveDriverLocation', (args) {
      receiveDriverLocation?.call(args);
    });

    //! receiveCurrentTrip Listeners
    _hubConnection.on('ReceiveCurrentTrip', (args) {
      receiveCurrentTrip?.call(args);
      log(
        'CurrentTrip received in Driver and client: $args',
        name: 'TripService',
      );
    });

    //! NewTripRequested Listeners
    _hubConnection.on('ReceiveNewTrip', (args) {
      newTripRequestedForDriver?.call(args);
      log('NewTrip requested for Driver: $args', name: 'TripService');
    });

    //! start Trip listeners
    _hubConnection.on('TripStartedForDriver', (args) {
      tripStartedForDriver?.call(args);
      log('TripStarted received in Driver: $args', name: 'TripService');
    });

    _hubConnection.on('TripStartedForClient', (args) {
      tripStartedForClient?.call(args);
      log('TripStarted received in Client: $args', name: 'TripService');
    });

    //! TripArrived Listeners
    _hubConnection.on('DriverArrivedTrip', (args) {
      driverArrivedTrip?.call(args);
      log('TripArrived received in Driver: $args', name: 'TripService');
    });

    _hubConnection.on('ClientArrivedTrip', (args) {
      clientArrivedTrip?.call(args);
      log('TripArrived received in Client: $args', name: 'TripService');
    });

    //! TripEnded Listeners
    _hubConnection.on('TripEndedForDriver', (args) {
      tripEndedForDriver?.call(args);
      log('TripEnded received in Driver: $args', name: 'TripService');
    });

    _hubConnection.on('TripEndedForClient', (args) {
      tripEndedForClient?.call(args);
      log('TripEnded received in Client: $args', name: 'TripService');
    });

    //! TripCanceled Listeners
    _hubConnection.on('TripCancelledByClient', (args) {
      tripCanceledByClient?.call(args);
      log('TripCancelled received to driver: $args', name: 'TripService');
    });
    _hubConnection.on('TripCancelledForClient', (args) {
      tripCanceledForClient?.call(args);
      log('TripCancelled received to Client: $args', name: 'TripService');
    });

    _hubConnection.on('TripCancelledForTripDriver', (args) {
      tripCanceledForTripDriver?.call(args);
      log('TripCancelled received to driver: $args', name: 'TripService');
    });

    //! TripTakenByDriver Listeners
    _hubConnection.on('TripTakenByAnotherDriver', (args) {
      tripTakenByAnotherDriver?.call(args);
      log('TripTakenByDriver received in Drivers: $args', name: 'TripService');
    });

    //! TripPaymentUpdated Listeners
    _hubConnection.on('TripPaymentUpdated', (args) {
      tripPaymentUpdated?.call(args);
      log(
        'TripPaymentUpdated received in Client and Drivers: $args',
        name: 'TripService',
      );
    });
  }

  Future<void> connect() async {
    if (_isConnected) return;

    try {
      await _hubConnection.start();
      _isConnected = true;
      log('Connected to TripHub', name: 'TripService');
    } catch (e) {
      log('Error connecting to TripHub: $e', name: 'TripService');
      throw 'حدث خطاء اثناء الاتصال , حاول مره اخرى';
    }
  }

  /// Ask the server to (re)push the caller's current trip (ReceiveCurrentTrip).
  /// Called on connect/reconnect/resume so the UI recovers after any missed
  /// events instead of being stuck on the last state it saw.
  Future<void> requestCurrentTrip() async {
    if (!_isConnected) return;
    // Backend UserTripRole enum: Client = 1, Driver = 2.
    final role = AppConstants.kRole == 'Driver' ? 2 : 1;
    try {
      await _hubConnection.invoke(
        'SendCurrentTrip',
        args: [AppConstants.kUserId, role],
      );
      log('Requested current-trip re-sync (role=$role)', name: 'TripService');
    } catch (e) {
      log('requestCurrentTrip failed: $e', name: 'TripService');
    }
  }

  Future<String> requestTrip(TripRequestModel tripRequest) async {
    if (!_isConnected) {
      log('Cannot request trip: Not connected to TripHub', name: 'TripService');
      throw 'حدث خطاء اثناء الاتصال , حاول مره اخرى';
    }

    try {
      final response =
          await _hubConnection.invoke(
                'RequestTrip',
                args: [tripRequest.toJson()],
              )
              as Map<String, dynamic>;
      final isSuccess = response['isSuccess'] as bool;
      if (!isSuccess) {
        throw '${response['message'] ?? 'حدث خطاء اثناء طلب الرحلة , حاول مره اخرى'}';
      }
      final data = response['data'] as Map<String, dynamic>;
      final tripId = data['id'] as String;
      log(
        'Trip requested from client: ${tripRequest.toJson()}, tripId: $tripId',
        name: 'TripService',
      );
      return tripId;
    } catch (e) {
      log('Error requesting trip: $e', name: 'TripService');
      throw 'حدث خطاء اثناء طلب الرحلة , حاول مره اخرى';
    }
  }

  Future<void> approveAndAssignDriverToTrip(
    String tripId,
    String driverLat,
    String driverLng,
  ) async {
    if (!_isConnected) {
      log('Cannot approve trip: Not connected to TripHub', name: 'TripService');
      throw 'حدث خطاء اثناء الاتصال , حاول مره اخرى';
    }

    try {
      await _hubConnection.invoke(
        'ApproveAndAssignDriverToTrip',
        args: [tripId, AppConstants.kUserId, driverLat, driverLng],
      );
      log(
        'Trip $tripId approved and assigned to driver ${AppConstants.kUserId}',
        name: 'TripService',
      );
    } catch (e) {
      log('Error approving trip: $e', name: 'TripService');
      throw 'حدث خطاء اثناء الموافقة على الرحلة , حاول مره اخرى';
    }
  }

  Future<void> startTrip(String tripId) async {
    if (!_isConnected) {
      log('Cannot start trip: Not connected to TripHub', name: 'TripService');
      throw 'حدث خطاء اثناء الاتصال , حاول مره اخرى';
    }

    try {
      await _hubConnection.invoke(
        'StartTrip',
        args: [tripId, AppConstants.kUserId],
      );
      log('Trip $tripId Started', name: 'TripService');
    } catch (e) {
      log('Error starting trip: $e', name: 'TripService');
      throw 'حدث خطاء اثناء بدء الرحلة , حاول مره اخرى';
    }
  }

  Future<void> endTrip(String tripId) async {
    if (!_isConnected) {
      log('Cannot end trip: Not connected to TripHub', name: 'TripService');
      throw 'حدث خطاء اثناء الاتصال , حاول مره اخرى';
    }

    try {
      await _hubConnection.invoke(
        'EndTrip',
        args: [tripId, AppConstants.kUserId],
      );
      log('Trip $tripId Ended', name: 'TripService');
    } catch (e) {
      log('Error Ending trip: $e', name: 'TripService');
      throw 'حدث خطاء اثناء انهاء الرحلة , حاول مره اخرى';
    }
  }

  Future<void> arrivedDriverToClient(String tripId) async {
    if (!_isConnected) {
      log('Cannot arrived trip: Not connected to TripHub', name: 'TripService');
      throw 'حدث خطاء اثناء الاتصال , حاول مره اخرى';
    }
    try {
      await _hubConnection.invoke(
        'Arrived',
        args: [tripId, AppConstants.kUserId],
      );
      log('Trip $tripId Arrived', name: 'TripService');
    } catch (e) {
      log('Error arrived trip: $e', name: 'TripService');
      throw 'حدث خطاء اثناء وصول السائق , حاول مره اخرى';
    }
  }

  Future<void> cancelTrip(String tripId, String userId, {String? reason}) async {
    // Cancelling only works over the socket. If the connection dropped (e.g.
    // after a network error) a pending trip would be impossible to cancel and
    // the user gets stuck on the "searching" screen — so reconnect and retry
    // instead of giving up on the first failure.
    if (!_isConnected) {
      log('Cancel: socket down, reconnecting first…', name: 'TripService');
      try {
        await connect();
      } catch (e) {
        log('Cancel: reconnect attempt failed: $e', name: 'TripService');
      }
    }

    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        await _hubConnection
            .invoke('CancelTripRequest', args: [tripId, userId, reason ?? '']);
        log('Trip $tripId Canceled (attempt $attempt)', name: 'TripService');
        return;
      } catch (e) {
        log('Error canceling trip (attempt $attempt): $e', name: 'TripService');
        if (attempt == 2) {
          throw 'حدث خطاء اثناء الغاء الرحلة , حاول مره اخرى';
        }
        // The connection likely died mid-invoke; force a fresh reconnect.
        _isConnected = false;
        try {
          await connect();
        } catch (e2) {
          log('Cancel: reconnect before retry failed: $e2', name: 'TripService');
        }
      }
    }
  }

  Future<void> payTripInCash(String tripId, String driverId) async {
    // Same resilience as cancelTrip: a dropped socket must not leave a trip
    // stuck on "awaiting payment" — reconnect and retry instead of failing.
    if (!_isConnected) {
      log('PayCash: socket down, reconnecting first…', name: 'TripService');
      try {
        await connect();
      } catch (e) {
        log('PayCash: reconnect attempt failed: $e', name: 'TripService');
      }
    }

    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        await _hubConnection.invoke('PayTripInCash', args: [tripId, driverId]);
        log('Trip $tripId Paid (attempt $attempt)', name: 'TripService');
        return;
      } catch (e) {
        log('Error paying trip (attempt $attempt): $e', name: 'TripService');
        if (attempt == 2) {
          throw 'حدث خطاء اثناء دفع الرحلة , حاول مره اخرى';
        }
        _isConnected = false;
        try {
          await connect();
        } catch (e2) {
          log('PayCash: reconnect before retry failed: $e2', name: 'TripService');
        }
      }
    }
  }

  Future<void> disconnect() async {
    if (!_isConnected) return;

    try {
      await _hubConnection.stop();
      _isConnected = false;
      log('Disconnected from TripHub', name: 'TripService');
    } catch (e) {
      log('Error disconnecting from TripHub: $e', name: 'TripService');
      rethrow;
    }
  }

  void dispose() => disconnect();
}
