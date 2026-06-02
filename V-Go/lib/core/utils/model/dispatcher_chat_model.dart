class DispatcherChatModel {
  final String id;
  final bool isOpen;
  final String clientName;
  final String clientId;
  final String? profilePicture;

  DispatcherChatModel({
    required this.id,
    required this.isOpen,
    required this.clientName,
    required this.clientId,
    this.profilePicture,
  });

  factory DispatcherChatModel.fromJson(Map<String, dynamic> json) {
    return DispatcherChatModel(
      id: json["id"],
      isOpen: json["isOpen"],
      clientName: json["clientName"],
      clientId: json["clientId"],
      profilePicture: json["profilePicture"],
    );
  }
}