import 'user_cubit.dart';

extension UserStatusExtension on UserStatus {
  bool get isInitial => this == UserStatus.initial;
  bool get isGetAllUsersSuccess => this == UserStatus.getAllUsersSuccess;
  bool get isGetAllUsersFailure => this == UserStatus.getAllUsersFailure;
  bool get isGetAllUsersLoading => this == UserStatus.getAllUsersLoading;
  bool get isGetUserDetailsSuccess => this == UserStatus.getUserDetailsSuccess;
  bool get isGetUserDetailsFailure => this == UserStatus.getUserDetailsFailure;
  bool get isGetUserDetailsLoading => this == UserStatus.getUserDetailsLoading;
  bool get isBlockOrUnblockUserSuccess =>
      this == UserStatus.blockOrUnblockUserSuccess;
  bool get isBlockOrUnblockUserFailure =>
      this == UserStatus.blockOrUnblockUserFailure;
  bool get isBlockOrUnblockUserLoading =>
      this == UserStatus.blockOrUnblockUserLoading;
  bool get isDeleteUserSuccess => this == UserStatus.deleteUserSuccess;
  bool get isDeleteUserFailure => this == UserStatus.deleteUserFailure;
  bool get isDeleteUserLoading => this == UserStatus.deleteUserLoading;
  bool get isAddUserSuccess => this == UserStatus.addUserSucess;
  bool get isAddUserFailure => this == UserStatus.addUserFailure;
  bool get isAddUserLoading => this == UserStatus.addUserLoading;
  bool get isUpdateUserSuccess => this == UserStatus.updateUserSuccess;
  bool get isUpdateUserFailure => this == UserStatus.updateUserFailure;
  bool get isUpdateUserLoading => this == UserStatus.updateUserLoading;
}
