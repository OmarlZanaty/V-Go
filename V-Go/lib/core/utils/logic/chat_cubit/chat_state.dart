part of 'chat_cubit.dart';

enum ChatStateStatus {
  initial,
  connecting,
  connected,
  sendMessageLoading,
  sendMessageSuccess,
  sendMessageFailure,
  getAllMessagesLoading,
  getAllMessagesSuccess,
  getAllMessagesFailure,
  messageReceived,
  closeChatLoading,
  closeChatSuccess,
  closeChatFailure,
  disconnecting,
  disconnected,
  getDispatcherChatsSuccess,
  getDispatcherChatsFailure,
  getDispatcherChatsLoading,
  error,
}

class ChatState extends Equatable {
  final ChatStateStatus status;
  final List<ChatMessageModel> messages;
  final List<DispatcherChatModel> dispatcherChats;
  final String errorMessage;
  final String successMessage;
  final int skip;
  final bool hasMoreMessages;
  final String chatId;

  const ChatState({
    this.status = ChatStateStatus.initial,
    this.messages = const [],
    this.dispatcherChats = const [],
    this.errorMessage = '',
    this.successMessage = '',
    this.skip = 0,
    this.hasMoreMessages = true,
    this.chatId = '',
  });

  ChatState copyWith({
    ChatStateStatus? status,
    List<ChatMessageModel>? messages,
    List<DispatcherChatModel>? dispatcherChats,
    String? errorMessage,
    String? successMessage,
    int? skip,
    bool? hasMoreMessages,
    String? chatId,
  }) {
    return ChatState(
      status: status ?? this.status,
      dispatcherChats: dispatcherChats ?? this.dispatcherChats,
      messages: messages ?? this.messages,
      errorMessage: errorMessage ?? this.errorMessage,
      successMessage: successMessage ?? this.successMessage,
      skip: skip ?? this.skip,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      chatId: chatId ?? this.chatId,
    );
  }

  @override
  List<Object?> get props => [
    status,
    messages,
    errorMessage,
    successMessage,
    dispatcherChats,
    skip,
    chatId,
    hasMoreMessages,
  ];
}
