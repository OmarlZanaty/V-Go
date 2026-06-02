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
  Function(List<Object?>?)? tripTakenByAnotherDriver;
  Function(List<Object?>?)? tripPaymentUpdated;

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

  Future<void> cancelTrip(String tripId, String userId) async {
    if (!_isConnected) {
      log('Cannot cancel trip: Not connected to TripHub', name: 'TripService');
      throw 'حدث خطاء اثناء الاتصال , حاول مره اخرى';
    }

    try {
      await _hubConnection.invoke('CancelTripRequest', args: [tripId, userId]);
      log('Trip $tripId Canceled', name: 'TripService');
    } catch (e) {
      log('Error canceling trip: $e', name: 'TripService');
      throw 'حدث خطاء اثناء الغاء الرحلة , حاول مره اخرى';
    }
  }

  Future<void> payTripInCash(String tripId, String driverId) async {
    if (!_isConnected) {
      log('Cannot pay trip: Not connected to TripHub', name: 'TripService');
      throw 'حدث خطاء اثناء الاتصال , حاول مره اخرى';
    }
    try {
      await _hubConnection.invoke('PayTripInCash', args: [tripId, driverId]);
      log('Trip $tripId Paid', name: 'TripService');
    } catch (e) {
      log('Error paying trip: $e', name: 'TripService');
      throw 'حدث خطاء اثناء دفع الرحلة , حاول مره اخرى';
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
