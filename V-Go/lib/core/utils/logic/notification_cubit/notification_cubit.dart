import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../api/api_service.dart';
import '../../../api/end_points.dart';
import '../../../errors/exception.dart';
import '../../model/notification_model.dart';

part 'notification_state.dart';

class NotificationCubit extends Cubit<NotificationState> {
  NotificationCubit(this._apiServices) : super(const NotificationState());
  final ApiServices _apiServices;

  Future<void> getNotifications({int pageNumber = 1, int pageSize = 10}) async {
    emit(state.copyWith(status: NotificationStatus.loading));
    try {
      final response = await _apiServices.get(
        EndPoint.getNotifications,
        queryParameters: {'pageNumber': pageNumber, 'pageSize': pageSize},
      );
      final allNotificationsResponse = AllNotificationsResponse.fromJson(response);
      emit(
        state.copyWith(
          status: NotificationStatus.success,
          notifications: state.notifications + allNotificationsResponse.notifications,
          hasNextPage: allNotificationsResponse.hasNextPage,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: NotificationStatus.failure,
          errorMessage: ServerFailure.fromError(e).errMessage,
        ),
      );
    }
  }
}
