import '../models/verification_models.dart';

abstract class VerificationRepo {
  Future<DriverVerification> getVerification();
  Future<DriverDocument> uploadDocument({
    required DriverDocumentType type,
    required String filePath,
    DateTime? expiryDate,
    void Function(int sent, int total)? onSendProgress,
  });
}
