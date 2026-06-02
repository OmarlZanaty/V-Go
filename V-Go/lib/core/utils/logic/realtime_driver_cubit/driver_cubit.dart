import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../errors/exception.dart';
import '../../../helpers/extensions.dart';
import '../../model/available_driver_model.dart';
import '../../model/driver_alert_model.dart';
import '../../model/driver_status_model.dart';
import '../../repo/driver_repo/driver_repo.dart';

part 'driver_state.dart';

class DriverCubit extends Cubit<DriverState> {
  final DriverRepo _driverRepo;

  DriverCubit(this._driverRepo) : super(const DriverState());

  Future<void> connect() async {
    emit(state.copyWith(status: DriverStatus.connecting));
    try {
      await _driverRepo.connect();
      emit(state.copyWith(status: DriverStatus.connected));
      _listenToDriverAlerts();
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: DriverStatus.error,
          errorMessage: 'حدث خطأ ما , يرجى المحاولة مجددا',
        ),
      );
    }
  }

  Future<void> updateDriverStatus(DriverStatusModel status) async {
    emit(state.copyWith(status: DriverStatus.updatStatusLoading));
    try {
      await _driverRepo.updateDriverStatus(status);
      emit(state.copyWith(status: DriverStatus.updateStatusSuccess));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: DriverStatus.updateStatusFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> sendAlertToAdmin(double lat, double lng) async {
    emit(state.copyWith(status: DriverStatus.sendAlertLoading));
    try {
      await _driverRepo.sendAlertToAdmin(lat, lng);
      emit(state.copyWith(status: DriverStatus.sendAlertSuccess));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: DriverStatus.sendAlertFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  void _listenToDriverAlerts() {
    _driverRepo.listenToDriverAlerts((data) {
      if (data.isNullOrEmpty()) return;
      final driverAlert = DriverAlertModel.fromJson(
        (data![0] as Map<String, dynamic>),
      );
      emit(
        state.copyWith(
          status: DriverStatus.receiveAlert,
          driverAlert: driverAlert,
        ),
      );
    });
  }

  Future<void> getAvailableDrivers() async {
    emit(state.copyWith(status: DriverStatus.fetchDriversLoading));
    try {
      final response = await _driverRepo.getAvailableDrivers();
      emit(
        state.copyWith(
          status: DriverStatus.fetchDriversSuccess,
          drivers: response,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: DriverStatus.fetchDriversFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> disconnect() async {
    emit(state.copyWith(status: DriverStatus.disconnected));
    try {
      await _driverRepo.disconnect();
      emit(state.copyWith(status: DriverStatus.disconnected));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: DriverStatus.error,
          errorMessage: 'حدث خطأ ما , يرجى المحاولة مجددا',
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _driverRepo.dispose();
    return super.close();
  }
}
