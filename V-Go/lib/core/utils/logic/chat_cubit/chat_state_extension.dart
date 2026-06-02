import 'chat_cubit.dart';

extension ChatStateStatusExtension on ChatStateStatus {
  bool get isConnecting => this == ChatStateStatus.connecting;
  bool get isConnected => this == ChatStateStatus.connected;
  bool get isSendMessageLoading => this == ChatStateStatus.sendMessageLoading;
  bool get isSendMessageSuccess => this == ChatStateStatus.sendMessageSuccess;
  bool get isSendMessageFailure => this == ChatStateStatus.sendMessageFailure;
  bool get isGetAllMessagesLoading =>
      this == ChatStateStatus.getAllMessagesLoading;
  bool get isGetAllMessagesSuccess =>
      this == ChatStateStatus.getAllMessagesSuccess;
  bool get isGetAllMessagesFailure =>
      this == ChatStateStatus.getAllMessagesFailure;
  bool get isMessageReceived => this == ChatStateStatus.messageReceived;
  bool get isCloseChatLoading => this == ChatStateStatus.closeChatLoading;
  bool get isCloseChatSuccess => this == ChatStateStatus.closeChatSuccess;
  bool get isCloseChatFailure => this == ChatStateStatus.closeChatFailure;
  bool get isDisconnecting => this == ChatStateStatus.disconnecting;
  bool get isDisconnected => this == ChatStateStatus.disconnected;
  bool get isGetDispatcherChatsSuccess =>
      this == ChatStateStatus.getDispatcherChatsSuccess;
  bool get isGetDispatcherChatsFailure =>
      this == ChatStateStatus.getDispatcherChatsFailure;
  bool get isGetDispatcherChatsLoading =>
      this == ChatStateStatus.getDispatcherChatsLoading;
  bool get isError => this == ChatStateStatus.error;
}
