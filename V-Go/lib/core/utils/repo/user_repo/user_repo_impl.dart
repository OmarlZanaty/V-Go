import '../../../../features/auth/data/model/register_request_model.dart';
import '../../../api/api_service.dart';
import '../../../api/end_points.dart';
import '../../../helpers/extensions.dart';
import '../../app_constants.dart';
import '../../model/update_user_request_model.dart';
import '../../model/user_model.dart';
import 'user_repo.dart';

class UserRepoImpl implements UserRepo {
  final ApiServices _apiServices;

  UserRepoImpl({required ApiServices apiServices}) : _apiServices = apiServices;

  @override
  Future<void> blockUser({required String userId}) async {
    await _apiServices.post(EndPoint.blockUser, data: [userId]);
  }

  @override
  Future<void> deleteUser({required String userId}) async {
    await _apiServices.post(EndPoint.deleteUser, data: [userId]);
  }

  @override
  Future<List<UserModel>> getAllUsers({required UserRole role}) async {
    final response = await _apiServices.get(
      EndPoint.allUsers,
      queryParameters: {'role': role.capitalized},
    );

    return response.map<UserModel>((e) => UserModel.fromJson(e)).toList();
  }

  @override
  Future<UserModel> getUserById({
    required String userId,
    bool isDriver = false,
  }) async {
    final response = await _apiServices.get(
      isDriver ? EndPoint.getDriverById(userId) : EndPoint.getUserById(userId),
    );
    return UserModel.fromJson(response);
  }

  @override
  Future<void> unblockUser({required String userId}) async {
    await _apiServices.post(EndPoint.unBlockUser, data: [userId]);
  }

  @override
  Future<String> addUser(RegisterRequestModel registerRequestModel) async {
    final response = await _apiServices.post(
      EndPoint.register,
      data: registerRequestModel.toJson(),
      isFormData: true,
    );
    return response['message'];
  }

  @override
  Future<void> updateUser({
    required String userId,
    required UpdateUserRequestModel updateUserRequestModel,
  }) async {
    await _apiServices.put(
      EndPoint.updateUser(userId),
      data: updateUserRequestModel.toJson(),
      isFormData: true,
    );
  }
}
