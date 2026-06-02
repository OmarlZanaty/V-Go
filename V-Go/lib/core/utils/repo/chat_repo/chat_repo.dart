import '../../model/chat_message_model.dart';
import '../../model/dispatcher_chat_model.dart';

abstract class ChatRepo {
  Future<List<ChatMessageModel>> getAllMessages({
    required String? chatId,
    required String userId,
    required int skip,
    required int take,
  });
  Future<List<DispatcherChatModel>> getAllDispatcherChats({
    required dispatcherId,
    required bool isOpen,
  });
}
