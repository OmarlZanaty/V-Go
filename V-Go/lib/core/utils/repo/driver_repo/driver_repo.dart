import '../../../api/api_service.dart';
import '../../../api/end_points.dart';
import '../../../services/driver_service.dart';
import '../../model/available_driver_model.dart';
import '../../model/driver_status_model.dart';

class DriverRepo {
  final DriverService _driverService;
  final ApiServices _apiService;
  DriverRepo(this._driverService, this._apiService);

  Future<void> connect() async {
    await _driverService.connect();
  }

  Future<void> disconnect() async {
    await _driverService.disconnect();
  }

  Future<void> updateDriverStatus(DriverStatusModel status) async {
    await _driverService.updateDriverStatus(status);
  }
  Future<void> sendAlertToAdmin(double lat, double lng) async {
    await _driverService.sendAlertToAdmin(lat, lng);
  }
  Future<void> listenToDriverAlerts(Function(List<Object?>?) onData) async {
    _driverService.receiveDriverAlert = onData;
  }

  Future<List<AvailableDriverModel>> getAvailableDrivers() async {
    final response = await _apiService.get(EndPoint.availableDrivers);
    return response
        .map<AvailableDriverModel>((e) => AvailableDriverModel.fromJson(e))
        .toList();
  }

  Future<void> dispose() async {
    await disconnect();
  }
}
