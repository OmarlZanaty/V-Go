class ChatMessageModel {
  final String? id;
  final String senderId;
  final String receiverId;
  final String chatId;
  final String content;
  final String sendAt;

  ChatMessageModel({
    required this.senderId,
    required this.content,
    required this.sendAt,
    required this.receiverId,
    required this.chatId,
    this.id,
  });
  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'],
      senderId: json['senderId'],
      receiverId: json['receiverId'],
      content: json['content'],
      chatId: json['chatId'],
      sendAt: json['sendAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'chatId': chatId,
      'message': content,
      'timestamp': sendAt,
    };
  }
}
