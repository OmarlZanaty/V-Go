class AllNotificationsResponse {
  final List<NotificationModel> notifications;
  final bool hasNextPage;
  AllNotificationsResponse({
    required this.notifications,
    required this.hasNextPage,
  });

  factory AllNotificationsResponse.fromJson(Map<String, dynamic> json) {
    return AllNotificationsResponse(
      notifications: json['data']
          .map<NotificationModel>((e) => NotificationModel.fromJson(e))
          .toList(),
      hasNextPage: json['hasNextPage'] as bool,
    );
  }
}

class NotificationModel {
  final int id;
  final String? title;
  final String? body;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.isRead,
    required this.createdAt,
    this.title,
    this.body,
  });
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as int,
      title: json['title'] as String?,
      body: json['body'] as String?,
      isRead: json['isRead'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
