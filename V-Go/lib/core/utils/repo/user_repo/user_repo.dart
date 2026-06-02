import '../../../../features/auth/data/model/register_request_model.dart';
import '../../app_constants.dart';
import '../../model/update_user_request_model.dart';
import '../../model/user_model.dart';

abstract class UserRepo {
  Future<List<UserModel>> getAllUsers({required UserRole role});
  Future<UserModel> getUserById({
    required String userId,
    bool isDriver = false,
  });
  Future<void> deleteUser({required String userId});
  Future<void> blockUser({required String userId});
  Future<void> unblockUser({required String userId});
  Future<String> addUser(RegisterRequestModel registerRequestModel);
  Future<void> updateUser({
    required String userId,
    required UpdateUserRequestModel updateUserRequestModel,
  });
}
