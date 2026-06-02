part of 'driver_cubit.dart';

enum DriverStatus {
  initial,
  connecting,
  connected,
  disconnected,
  updatStatusLoading,
  updateStatusSuccess,
  updateStatusFailure,
  fetchDriversLoading,
  fetchDriversSuccess,
  fetchDriversFailure,
  sendAlertLoading,
  sendAlertSuccess,
  sendAlertFailure,
  receiveAlert,
  error,
}

class DriverState extends Equatable {
  final DriverStatus status;
  final String errorMessage;
  final String successMessage;
  final List<AvailableDriverModel> drivers;
  final DriverAlertModel? driverAlert;

  const DriverState({
    this.status = DriverStatus.initial,
    this.errorMessage = '',
    this.successMessage = '',
    this.drivers = const [],
    this.driverAlert,
  });

  DriverState copyWith({
    DriverStatus? status,
    String? errorMessage,
    String? successMessage,
    List<AvailableDriverModel>? drivers,
    DriverAlertModel? driverAlert,
  }) {
    return DriverState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      drivers: drivers ?? this.drivers,
      successMessage: successMessage ?? this.successMessage,
      driverAlert: driverAlert ?? this.driverAlert,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage, drivers, successMessage, driverAlert];
}
