import 'dart:developer';

import 'package:signalr_netcore/signalr_client.dart';

import '../config/app_config.dart';
import '../utils/app_constants.dart';
import '../utils/model/driver_status_model.dart';

class DriverService {
  late final HubConnection _hubConnection;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Function(List<Object?>?)? receiveDriverAlert;

  DriverService() {
    _initializeHubConnection();
  }

  void _initializeHubConnection() {
    _hubConnection = HubConnectionBuilder()
        .withUrl(
          AppConfig.hubUrl('driverHub'),
          options: HttpConnectionOptions(
            requestTimeout: 60000,
            accessTokenFactory: () async => AppConstants.kToken,
          ),
        )
        .withAutomaticReconnect()
        .build();

    _hubConnection.on('ReceiveDriverAlert', (args) {
      receiveDriverAlert?.call(args);
      log('Driver alert received: $args', name: 'DriverService');
    });

    _hubConnection.onclose(({error}) {
      _isConnected = false;
      log(
        'DriverHub connection closed: ${error?.toString()}',
        name: 'DriverService',
      );
    });
  }

  Future<void> connect() async {
    if (_isConnected) return;
    try {
      await _hubConnection.start();
      _isConnected = true;
      log('Connected to DriverHub', name: 'DriverService');
    } catch (e) {
      log('Error connecting to DriverHub: $e', name: 'DriverService');
      throw 'حدث خطاء اثناء الاتصال , حاول مره اخرى';
    }
  }

  Future<void> updateDriverStatus(DriverStatusModel status) async {
    if (!_isConnected) {
      log(
        'Cannot update driver status: Not connected to DriverHub',
        name: 'DriverService',
      );
      throw 'حدث خطاء اثناء تحديث حالة السائق , حاول مره اخرى';
    }

    try {
      await _hubConnection.invoke(
        'UpdateDriverStatus',
        args: [status.toJson()],
      );
      log('Driver status updated: ${status.toJson()}', name: 'DriverService');
    } catch (e) {
      log('Error updating driver status: $e', name: 'DriverService');
      throw 'حدث خطاء اثناء تحديث حالة السائق , حاول مره اخرى';
    }
  }

  Future<void> sendAlertToAdmin(double lat, double lng) async {
    if (!_isConnected) {
      log(
        'Cannot send alert: Not connected to DriverHub',
        name: 'DriverService',
      );
      throw 'حدث خطاء اثناء الاتصال وارسال التنبيه , حاول مره اخرى';
    }

    try {
      await _hubConnection.invoke('SendAlertToAdmin', args: [lat, lng]);
      log('Alert sent: $lat, $lng', name: 'DriverService');
    } catch (e) {
      log('Error sending alert: $e', name: 'DriverService');
      throw 'حدث خطاء اثناء ارسال التنبيه , حاول مره اخرى';
    }
  }

  Future<void> disconnect() async {
    if (!_isConnected) return;

    try {
      await _hubConnection.stop();
      _isConnected = false;
      log('Disconnected from DriverHub', name: 'DriverService');
    } catch (e) {
      log('Error disconnecting from DriverHub: $e', name: 'DriverService');
      rethrow;
    }
  }
}
