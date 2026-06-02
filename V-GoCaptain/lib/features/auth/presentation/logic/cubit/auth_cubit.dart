import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/api/dio_factory.dart';
import '../../../../../core/cache/cache_helper.dart';
import '../../../../../core/errors/exception.dart';
import '../../../../../core/utils/app_constants.dart';
import '../../../data/model/login_response_model.dart';
import '../../../data/repo/auth_repo.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepo _authRepo;
  AuthCubit(this._authRepo) : super(const AuthInitial());

  Future<void> login({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      emit(const AuthError('برجاء إدخال البريد الإلكتروني وكلمة المرور'));
      return;
    }

    emit(const AuthLoading());
    try {
      final fcmToken = await CacheHelper.getSecuredString(AppConstants.fcmToken);
      final result = await _authRepo.login(
        email: email.trim(),
        password: password,
        fcmToken: fcmToken,
        deviceType: AppConstants.deviceType,
      );

      // This app is for drivers only — reject any other role.
      if (result.role != AppConstants.driverRole) {
        emit(const AuthError('هذا التطبيق مخصص للكباتن فقط'));
        return;
      }

      await _persistSession(result);
      emit(AuthSuccess(result.role));
    } on ServerFailure catch (f) {
      emit(AuthError(f.errMessage));
    } catch (e) {
      emit(AuthError(ServerFailure.fromError(e).errMessage));
    }
  }

  Future<void> _persistSession(LoginResponseModel result) async {
    await CacheHelper.setSecuredString(AppConstants.token, result.token);
    await CacheHelper.setSecuredString(
      AppConstants.refreshToken,
      result.refreshToken,
    );
    await CacheHelper.setSecuredString(AppConstants.userId, result.userId);
    await CacheHelper.setData(key: AppConstants.role, value: result.role);

    AppConstants.kToken = result.token;
    AppConstants.kUserId = result.userId;
    AppConstants.kRole = result.role;

    await DioFactory.setTokenIntoHeaderAfterLogin(result.token);
  }
}
