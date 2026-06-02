import '../../../api/api_service.dart';
import '../../../api/end_points.dart';
import '../../model/chat_message_model.dart';
import '../../model/dispatcher_chat_model.dart';
import 'chat_repo.dart';

class ChatRepoImpl implements ChatRepo {
  final ApiServices _apiServices;

  ChatRepoImpl({required ApiServices apiServices}) : _apiServices = apiServices;

  @override
  Future<List<DispatcherChatModel>> getAllDispatcherChats({
    required dispatcherId,
    required bool isOpen,
  }) async {
    final response = await _apiServices.get(
      EndPoint.getDispatcherChats,
      queryParameters: {'dispatcherId': dispatcherId, 'isOpen': isOpen},
    );
    return response
        .map<DispatcherChatModel>((e) => DispatcherChatModel.fromJson(e))
        .toList();
  }

  @override
  Future<List<ChatMessageModel>> getAllMessages({
    required String? chatId,
    required String userId,
    required int skip,
    required int take,
  }) async {
    final response = await _apiServices.get(
      EndPoint.getChatMessages,
      queryParameters: {'chatId': chatId, 'skip': skip, 'take': take, 'userId': userId},
    );
    return response
        .map<ChatMessageModel>((e) => ChatMessageModel.fromJson(e))
        .toList();
  }
}
