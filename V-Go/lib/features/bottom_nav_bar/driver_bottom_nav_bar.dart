// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lazy_load_indexed_stack/lazy_load_indexed_stack.dart';

import '../../../core/di/di.dart';
import '../../core/helpers/double_back_to_exit.dart';
import '../../core/utils/app_constants.dart';
import '../../core/utils/logic/notification_cubit/notification_cubit.dart';
import '../../core/utils/logic/realtime_driver_cubit/driver_cubit.dart';
import '../../core/utils/logic/user_cubit/user_cubit.dart';
import '../driver/presentation/views/driver_dashbord.dart';
import '../driver/presentation/views/notification_view.dart';
import '../settings/settings_view.dart';
import '../trips/presentation/logic/realtime_trip_cubit/realtime_trip_cubit.dart';
import '../trips/presentation/logic/trip_cubit/trip_cubit.dart';
import '../trips/presentation/views/all_trips_view.dart';
import 'custom_bottom_nav_bar.dart';

class DriverBottomNavBarView extends StatefulWidget {
  const DriverBottomNavBarView({super.key});

  @override
  State<DriverBottomNavBarView> createState() => _DriverBottomNavBarViewState();
}

class _DriverBottomNavBarViewState extends State<DriverBottomNavBarView> {
  int currentIndex = 0;

  List<Widget> _buildIndexedStackChildren() {
    return [
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                UserCubit(getIt())
                  ..getUserDetails(AppConstants.kUserId, isDriver: true),
          ),
          BlocProvider(create: (context) => DriverCubit(getIt())..connect()),
          BlocProvider(
            create: (context) => RealTimeTripCubit(getIt())..connect(),
          ),
        ],
        child: const DriverDashbord(),
      ),
      BlocProvider(
        create: (context) =>
            (TripCubit(getIt())..getAllTrips(userId: AppConstants.kUserId)),
        child: AllTripsView(userId: AppConstants.kUserId),
      ),
      BlocProvider(
        create: (context) => NotificationCubit(getIt())..getNotifications(),
        child: const NotificationView(),
      ),
      const SettingsView(isDriver: true),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return DoubleBackToExitWrapper(
      child: Scaffold(
        body: LazyLoadIndexedStack(
          index: currentIndex,
          children: _buildIndexedStackChildren(),
        ),
        bottomNavigationBar: CustomBottomNavBar(
          isDriver: true,
          onTabTapped: (index) {
            setState(() => currentIndex = index);
          },
        ),
      ),
    );
  }
}
