import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/utils/logic/notification_cubit/notification_cubit.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_failure_widget.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_refresh_indicator.dart';
import '../widgets/notification_item.dart';

class NotificationView extends StatefulWidget {
  const NotificationView({super.key});

  @override
  State<NotificationView> createState() => _NotificationViewState();
}

class _NotificationViewState extends State<NotificationView> {
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final cubit = context.read<NotificationCubit>();
    if (_paginationCheck(cubit)) {
      _currentPage++;
      cubit.getNotifications(pageNumber: _currentPage);
    }
  }

  bool _paginationCheck(NotificationCubit cubit) {
    return cubit.state.hasNextPage &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.9 &&
        _scrollController.position.userScrollDirection ==
            ScrollDirection.reverse &&
        !cubit.state.status.isLoading;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: 'الاشعارات'),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: BlocBuilder<NotificationCubit, NotificationState>(
          buildWhen: (previous, current) => _buildWhen(current),
          builder: (context, state) {
            if (state.status.isSuccess ||
                (state.status.isLoading && state.notifications.isNotEmpty)) {
              final notifications = state.notifications;
              final bool showLoadingIndicator = state.status.isLoading;

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount:
                    notifications.length + (showLoadingIndicator ? 1 : 0),
                itemBuilder: (BuildContext context, int index) {
                  if (index == notifications.length && showLoadingIndicator) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CustomLoadingWidget(),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: NotificationItem(notification: notifications[index]),
                  );
                },
              );
            } else if (state.status.isFailure) {
              return CustomRefreshIndicator(
                onRefresh: () async {
                  context.read<NotificationCubit>().getNotifications();
                },
                child: ListView(
                  children: [
                    SizedBox(
                      height: 0.8.sh,
                      child: CustomFailureWidget(text: state.errorMessage),
                    ),
                  ],
                ),
              );
            }
            return const CustomLoadingWidget();
          },
        ),
      ),
    );
  }

  bool _buildWhen(NotificationState state) =>
      state.status.isLoading ||
      state.status.isSuccess ||
      state.status.isFailure;
}
