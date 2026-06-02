part of 'notification_cubit.dart';

enum NotificationStatus { initial, loading, success, failure }


extension NotificationStatusExtension on NotificationStatus {
  bool get isInitial => this == NotificationStatus.initial;
  bool get isLoading => this == NotificationStatus.loading;
  bool get isSuccess => this == NotificationStatus.success;
  bool get isFailure => this == NotificationStatus.failure;
}

class NotificationState extends Equatable {
  final NotificationStatus status;
  final List<NotificationModel> notifications;
  final bool hasNextPage;
  final String errorMessage;

  const NotificationState({
    this.status = NotificationStatus.initial,
    this.notifications = const [],
    this.hasNextPage = false,
    this.errorMessage = '',
  });

  NotificationState copyWith({
    NotificationStatus? status,
    List<NotificationModel>? notifications,
    String? errorMessage,
    bool? hasNextPage,
  }) {
    return NotificationState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
      errorMessage: errorMessage ?? this.errorMessage,
      hasNextPage: hasNextPage ?? this.hasNextPage,
    );
  }

  @override
  List<Object?> get props => [status, notifications, errorMessage, hasNextPage];
}
