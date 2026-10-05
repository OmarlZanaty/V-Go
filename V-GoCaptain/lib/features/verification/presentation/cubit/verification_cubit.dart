import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/cache/cache_helper.dart';
import '../../../../core/errors/exception.dart';
import '../../../../core/utils/app_constants.dart';
import '../../data/models/verification_models.dart';
import '../../data/repo/verification_repo.dart';

part 'verification_state.dart';

class VerificationCubit extends Cubit<VerificationState> {
  VerificationCubit(this._repo) : super(const VerificationState());

  final VerificationRepo _repo;

  Future<void> load() async {
    emit(
      state.copyWith(status: VerificationLoadStatus.loading, clearError: true),
    );
    try {
      final verification = await _repo.getVerification();
      await _syncProfilePicture(verification);
      emit(
        state.copyWith(
          status: VerificationLoadStatus.loaded,
          verification: verification,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: VerificationLoadStatus.error,
          error: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> uploadDocument({
    required DriverDocumentType type,
    required String filePath,
    DateTime? expiryDate,
  }) async {
    emit(
      state.copyWith(
        uploadingType: type,
        uploadProgress: 0,
        clearError: true,
        clearSuccess: true,
      ),
    );
    try {
      await _repo.uploadDocument(
        type: type,
        filePath: filePath,
        expiryDate: expiryDate,
        onSendProgress: (sent, total) {
          if (total <= 0 || isClosed) return;
          emit(state.copyWith(uploadProgress: sent / total));
        },
      );
      final verification = await _repo.getVerification();
      await _syncProfilePicture(verification);
      emit(
        state.copyWith(
          status: VerificationLoadStatus.loaded,
          verification: verification,
          clearUploadingType: true,
          uploadProgress: 0,
          success: 'تم رفع المستند وبقى قيد المراجعة',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          clearUploadingType: true,
          uploadProgress: 0,
          error: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> _syncProfilePicture(DriverVerification verification) async {
    final picture = (verification.profilePicture ?? '').trim();
    if (picture.isEmpty) return;
    AppConstants.kProfileImage = picture;
    await CacheHelper.setData(key: AppConstants.profileImage, value: picture);
  }
}
