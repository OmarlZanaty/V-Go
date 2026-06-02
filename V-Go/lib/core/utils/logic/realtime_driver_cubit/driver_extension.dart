import 'driver_cubit.dart';

extension RealTimeDriverStateStatusExtension on DriverStatus {
  bool get isConnecting => this == DriverStatus.connecting;
  bool get isConnected => this == DriverStatus.connected;
  bool get isDisconnected => this == DriverStatus.disconnected;
  bool get isUpdateStatusLoading => this == DriverStatus.updatStatusLoading;
  bool get isUpdateStatusSuccess => this == DriverStatus.updateStatusSuccess;
  bool get isUpdateStatusFailure => this == DriverStatus.updateStatusFailure;
  bool get isFetchDriversLoading => this == DriverStatus.fetchDriversLoading;
  bool get isFetchDriversSuccess => this == DriverStatus.fetchDriversSuccess;
  bool get isFetchDriversFailure => this == DriverStatus.fetchDriversFailure;
  bool get isSendAlertLoading => this == DriverStatus.sendAlertLoading;
  bool get isSendAlertSuccess => this == DriverStatus.sendAlertSuccess;
  bool get isSendAlertFailure => this == DriverStatus.sendAlertFailure;
  bool get isReceiveAlert => this == DriverStatus.receiveAlert;
  bool get isError => this == DriverStatus.error;
}
