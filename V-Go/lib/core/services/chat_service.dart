import 'dart:developer';

import 'package:signalr_netcore/signalr_client.dart';

import '../config/app_config.dart';
import '../utils/app_constants.dart';

class ChatService {
  late final HubConnection _hubConnection;
  Function(List<Object?>?)? onMessageReceived;
  bool _isConnected = false;

  ChatService() {
    _initializeHubConnection();
  }

  void _initializeHubConnection() {
    _hubConnection = HubConnectionBuilder()
        .withUrl(
          AppConfig.hubUrl('supportChatHub'),
          options: HttpConnectionOptions(
            requestTimeout: 60000,
            accessTokenFactory: () async => AppConstants.kToken,
          ),
        )
        .withAutomaticReconnect()
        .build();

    _hubConnection.onclose(({error}) {
      _isConnected = false;
      log('Connection closed: ${error?.toString()}', name: 'ChatService');
    });
  }

  Future<void> connect() async {
    if (_isConnected) return;

    try {
      await _hubConnection.start();
      _isConnected = true;
      log('Connected to SignalR hub', name: 'ChatService');
      _setupMessageReceiving();
    } catch (e) {
      log('Error connecting to SignalR hub: $e', name: 'ChatService');
      throw 'حدث خطاء اثناء الاتصال , حاول مره اخرى';
    }
  }

  void _setupMessageReceiving() {
    _hubConnection.on('ReceiveSupportMessage', (arguments) {
      onMessageReceived?.call(arguments);
      log('Received message: $arguments', name: 'ChatService');
    });
  }

  Future<void> sendSupportMessageAsync(
    String content,
    String senderId,
    String chatId,
  ) async {
    if (!_isConnected) {
      log(
        'Cannot send message: Not connected to SignalR hub',
        name: 'ChatService',
      );
      throw 'حدث خطاء اثناء الاتصال وارسال الرسالة , حاول مره اخرى';
    }
    try {
      await _hubConnection.invoke(
        'SendSupportMessage',
        args: [senderId, content, chatId],
      );
      log('Message sent: $content', name: 'ChatService');
    } catch (e) {
      log('Error sending message: $e', name: 'ChatService');
      throw 'حدث خطاء اثناء ارسال الرسالة , حاول مره اخرى';
    }
  }

  Future<void> closeChat(String chatId) async {
    if (!_isConnected) {
      log(
        'Cannot close chat: Not connected to SignalR hub',
        name: 'ChatService',
      );
      throw 'حدث خطاء اثناء الاتصال واغلاق الدردشة , حاول مره اخرى';
    }

    try {
      await _hubConnection.invoke('CloseChat', args: [chatId]);
      log('Chat closed: $chatId', name: 'ChatService');
    } catch (e) {
      log('Error closing chat: $e', name: 'ChatService');
      throw 'حدث خطاء اثناء اغلاق الدردشة , حاول مره اخرى';
    }
  }

  Future<void> disconnect() async {
    if (!_isConnected) return;

    try {
      await _hubConnection.stop();
      _isConnected = false;
      log('Disconnected from SignalR hub', name: 'ChatService');
    } catch (e) {
      log('Error disconnecting from SignalR hub: $e', name: 'ChatService');
      throw 'حدث خطاء اثناء اغلاق الاتصال';
    }
  }

  void dispose() => disconnect();
}
