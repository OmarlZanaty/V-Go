import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../errors/exception.dart';
import '../../../services/chat_service.dart';
import '../../app_constants.dart';
import '../../model/chat_message_model.dart';
import '../../model/dispatcher_chat_model.dart';
import '../../repo/chat_repo/chat_repo.dart';
import 'chat_state_extension.dart';

part 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  final ChatService _chatService;
  final ChatRepo _chatRepo;

  ChatCubit(this._chatService, this._chatRepo) : super(const ChatState());

  Future<void> connect({required String chatId}) async {
    emit(state.copyWith(status: ChatStateStatus.connecting, chatId: chatId));
    try {
      await _chatService.connect();
      emit(state.copyWith(status: ChatStateStatus.connected));
      _onRecieveSupportMessages();
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ChatStateStatus.error,
          errorMessage: 'حدث خطأ ما , يرجى المحاولة مجددا',
        ),
      );
    }
  }

  void _onRecieveSupportMessages() {
    _chatService.onMessageReceived = (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final messageMap = arguments[0] as Map<String, dynamic>;
        final newMessage = ChatMessageModel.fromJson(messageMap);

        if (!state.messages.any((msg) => msg.sendAt == newMessage.sendAt)) {
          emit(
            state.copyWith(
              status: ChatStateStatus.getAllMessagesSuccess,
              messages: [newMessage, ...state.messages],
              chatId: newMessage.chatId,
            ),
          );
        }
      }
    };
  }

  Future<void> sendMessage(String content) async {
    emit(state.copyWith(status: ChatStateStatus.sendMessageLoading));
    try {
      final ChatMessageModel message = ChatMessageModel(
        id: '',
        senderId: AppConstants.kUserId,
        receiverId: '',
        chatId: state.chatId,
        content: content,
        sendAt: DateTime.now().toIso8601String(),
      );
      await _chatService.sendSupportMessageAsync(
        content,
        AppConstants.kUserId,
        state.chatId,
      );
      emit(state.copyWith(status: ChatStateStatus.sendMessageSuccess));
      emit(
        state.copyWith(
          status: ChatStateStatus.getAllMessagesSuccess,
          messages: [message, ...state.messages],
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ChatStateStatus.sendMessageFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> getAllMessages() async {
    emit(state.copyWith(status: ChatStateStatus.getAllMessagesLoading));
    try {
      final messages = await _chatRepo.getAllMessages(
        chatId: state.chatId,
        userId: AppConstants.kUserId,
        skip: 0,
        take: 30,
      );

      emit(
        state.copyWith(
          status: ChatStateStatus.getAllMessagesSuccess,
          messages: messages,
          skip: 0,
          hasMoreMessages: messages.length == 30,
          chatId: messages.isNotEmpty ? messages[0].chatId : state.chatId,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ChatStateStatus.getAllMessagesFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> loadMoreMessages({required int take}) async {
    if (state.status.isCloseChatLoading || !state.hasMoreMessages) return;

    final newSkip = state.skip + state.messages.length;
    emit(state.copyWith(status: ChatStateStatus.getAllMessagesLoading));

    try {
      final newMessages = await _chatRepo.getAllMessages(
        chatId: state.chatId,
        userId: AppConstants.kUserId,
        skip: newSkip,
        take: take,
      );
      emit(
        state.copyWith(
          status: ChatStateStatus.getAllMessagesSuccess,
          messages: [...state.messages, ...newMessages],
          skip: newSkip,
          hasMoreMessages: newMessages.length == take,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ChatStateStatus.getAllMessagesFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> getAllDispatcherChats({required dispatcherId}) async {
    emit(state.copyWith(status: ChatStateStatus.getDispatcherChatsLoading));
    try {
      final dispatcherChats = await _chatRepo.getAllDispatcherChats(
        dispatcherId: dispatcherId,
        isOpen: true,
      );
      emit(
        state.copyWith(
          status: ChatStateStatus.getDispatcherChatsSuccess,
          dispatcherChats: dispatcherChats,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ChatStateStatus.getDispatcherChatsFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> closeChat() async {
    emit(state.copyWith(status: ChatStateStatus.closeChatLoading));
    try {
      await _chatService.closeChat(state.chatId);
      emit(
        state.copyWith(
          status: ChatStateStatus.closeChatSuccess,
          successMessage: 'تم إغلاق الدردشة بنجاح',
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ChatStateStatus.closeChatFailure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }

  Future<void> disconnect() async {
    emit(state.copyWith(status: ChatStateStatus.disconnecting));
    try {
      await _chatService.disconnect();
      emit(state.copyWith(status: ChatStateStatus.disconnected));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ChatStateStatus.error,
          errorMessage: 'حدث خطأ ما , يرجى المحاولة مجددا',
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _chatService.dispose();
    return super.close();
  }
}
