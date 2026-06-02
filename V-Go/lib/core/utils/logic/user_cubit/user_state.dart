part of 'user_cubit.dart';

enum UserStatus {
  initial,
  getAllUsersSuccess,
  getAllUsersFailure,
  getAllUsersLoading,
  getUserDetailsSuccess,
  getUserDetailsFailure,
  getUserDetailsLoading,
  blockOrUnblockUserSuccess,
  blockOrUnblockUserFailure,
  blockOrUnblockUserLoading,
  deleteUserSuccess,
  deleteUserFailure,
  deleteUserLoading,
  addUserLoading,
  addUserSucess,
  addUserFailure,
  updateUserLoading,
  updateUserSuccess,
  updateUserFailure,
}

class UserState extends Equatable {
  final UserStatus status;
  final String errorMessage;
  final String successMessage;
  final List<UserModel> users;
  final List<UserModel> searchedUsers;
  final UserModel? userDetails;
  const UserState({
    this.status = UserStatus.initial,
    this.errorMessage = '',
    this.successMessage = '',
    this.users = const [],
    this.searchedUsers = const [],
    this.userDetails,
  });

  UserState copyWith({
    UserStatus? status,
    String? errorMessage,
    String? successMessage,
    List<UserModel>? users,
    List<UserModel>? searchedUsers,
    UserModel? userDetails,
    File? profileImage,
  }) {
    return UserState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      successMessage: successMessage ?? this.successMessage,
      users: users ?? this.users,
      searchedUsers: searchedUsers ?? this.searchedUsers,
      userDetails: userDetails ?? this.userDetails,
    );
  }

  @override
  List<Object?> get props => [
    status,
    errorMessage,
    successMessage,
    users,
    userDetails,
    searchedUsers,
  ];
}
