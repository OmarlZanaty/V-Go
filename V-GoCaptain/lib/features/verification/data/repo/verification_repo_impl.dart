import 'package:dio/dio.dart';

import '../../../../core/api/api_envelope.dart';
import '../../../../core/api/api_service.dart';
import '../../../../core/api/end_points.dart';
import '../models/verification_models.dart';
import 'verification_repo.dart';

class VerificationRepoImpl implements VerificationRepo {
  VerificationRepoImpl({required ApiServices apiServices}) : _api = apiServices;

  final ApiServices _api;

  @override
  Future<DriverVerification> getVerification() async {
    final data = ApiEnvelope.data(
      await _api.get(EndPoint.driverVerificationMe),
    );
    return DriverVerification.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<DriverDocument> uploadDocument({
    required DriverDocumentType type,
    required String filePath,
    DateTime? expiryDate,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final data = ApiEnvelope.data(
      await _api.post(
        EndPoint.driverVerificationDocuments,
        isFormData: true,
        onSendProgress: onSendProgress,
        data: {
          'type': type.apiValue,
          'file': await MultipartFile.fromFile(filePath),
          if (expiryDate != null) 'expiryDate': _date(expiryDate),
        },
      ),
    );
    return DriverDocument.fromJson(Map<String, dynamic>.from(data as Map));
  }

  String _date(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}
