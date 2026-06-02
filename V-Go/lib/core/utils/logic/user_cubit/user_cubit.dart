import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../features/auth/data/model/register_request_model.dart';
import '../../../errors/exception.dart';
import '../../app_constants.dart';
import '../../model/update_user_request_model.dart';
import '../../model/user_model.dart';
import '../../repo/user_repo/user_repo.dart';

part 'user_state.dart';

class UserCubit extends Cubit<UserState> {
  UserCubit(this._userRepo) : super(const UserState());
  final UserRepo _userRepo;

  Future<void> getAllUsers({required UserRole role}) async {
    emit(state.copyWith(status: UserStatus.getAllUsersLoading));
    try {
      final users = await _userRepo.getAllUsers(role: role);
      emit(state.copyWith(status: UserStatus.getAllUsersSuccess, users: users));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: UserStatus.getAllUsersFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  void searchUsers(String query) {
    if (query.isEmpty) {
      emit(
        state.copyWith(
          status: UserStatus.getAllUsersSuccess,
          searchedUsers: state.users,
        ),
      );
    } else {
      final filtered = state.users
          .where(
            (user) => user.name.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
      if (filtered.isEmpty) {
        emit(
          state.copyWith(
            status: UserStatus.getAllUsersFailure,
            errorMessage: 'لا يوجد مستخدمين بهذا الاسم',
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: UserStatus.getAllUsersSuccess,
          searchedUsers: filtered,
        ),
      );
    }
  }

  Future<void> getUserDetails(String userId, {bool isDriver = false}) async {
    emit(state.copyWith(status: UserStatus.getUserDetailsLoading));
    try {
      final user = await _userRepo.getUserById(
        userId: userId,
        isDriver: isDriver,
      );
      emit(
        state.copyWith(
          status: UserStatus.getUserDetailsSuccess,
          userDetails: user,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: UserStatus.getUserDetailsFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  void updateDriverAvailability(bool isAvailable) {
    final updatedUser = state.userDetails?.copyWith(isAvailable: isAvailable);
    emit(
      state.copyWith(
        status: UserStatus.getUserDetailsSuccess,
        userDetails: updatedUser,
      ),
    );
  }

  Future<void> blockOrUnblockUser(
    String userId, {
    required bool isBlocked,
  }) async {
    emit(state.copyWith(status: UserStatus.blockOrUnblockUserLoading));
    try {
      isBlocked
          ? await _userRepo.unblockUser(userId: userId)
          : await _userRepo.blockUser(userId: userId);
      emit(
        state.copyWith(
          status: UserStatus.blockOrUnblockUserSuccess,
          successMessage: isBlocked
              ? 'تم فك حظر المستخدم بنجاح'
              : 'تم حظر المستخدم بنجاح',
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: UserStatus.blockOrUnblockUserFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> deleteUser(String userId) async {
    emit(state.copyWith(status: UserStatus.deleteUserLoading));
    try {
      await _userRepo.deleteUser(userId: userId);
      emit(
        state.copyWith(
          status: UserStatus.deleteUserSuccess,
          successMessage: 'تم حذف المستخدم بنجاح',
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: UserStatus.deleteUserFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> addUser(RegisterRequestModel registerRequestModel) async {
    emit(state.copyWith(status: UserStatus.addUserLoading));
    try {
      final result = await _userRepo.addUser(registerRequestModel);
      emit(
        state.copyWith(
          status: UserStatus.addUserSucess,
          successMessage: result,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: UserStatus.addUserFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> updateUser(
    String userId,
    UpdateUserRequestModel updateUserForAdminModel,
  ) async {
    emit(state.copyWith(status: UserStatus.updateUserLoading));
    try {
      await _userRepo.updateUser(
        userId: userId,
        updateUserRequestModel: updateUserForAdminModel,
      );
      emit(
        state.copyWith(
          status: UserStatus.updateUserSuccess,
          successMessage: 'تم تحديث البيانات بنجاح',
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: UserStatus.updateUserFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }
}
