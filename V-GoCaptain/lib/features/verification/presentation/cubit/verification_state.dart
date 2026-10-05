part of 'verification_cubit.dart';

enum VerificationLoadStatus { initial, loading, loaded, error }

class VerificationState extends Equatable {
  const VerificationState({
    this.status = VerificationLoadStatus.initial,
    this.verification,
    this.uploadingType,
    this.uploadProgress = 0,
    this.error,
    this.success,
  });

  final VerificationLoadStatus status;
  final DriverVerification? verification;
  final DriverDocumentType? uploadingType;
  final double uploadProgress;
  final String? error;
  final String? success;

  VerificationState copyWith({
    VerificationLoadStatus? status,
    DriverVerification? verification,
    DriverDocumentType? uploadingType,
    bool clearUploadingType = false,
    double? uploadProgress,
    String? error,
    bool clearError = false,
    String? success,
    bool clearSuccess = false,
  }) {
    return VerificationState(
      status: status ?? this.status,
      verification: verification ?? this.verification,
      uploadingType: clearUploadingType
          ? null
          : (uploadingType ?? this.uploadingType),
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: clearError ? null : error,
      success: clearSuccess ? null : success,
    );
  }

  @override
  List<Object?> get props => [
    status,
    verification,
    uploadingType,
    uploadProgress,
    error,
    success,
  ];
}
