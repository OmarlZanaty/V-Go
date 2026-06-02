// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lazy_load_indexed_stack/lazy_load_indexed_stack.dart';

import '../../../core/di/di.dart';
import '../../core/helpers/double_back_to_exit.dart';
import '../../core/utils/app_constants.dart';
import '../../core/utils/logic/user_cubit/user_cubit.dart';
import '../client/presentation/views/client_dashboard_view.dart';
import '../client/presentation/views/client_profile_details_view.dart';
import '../settings/settings_view.dart';
import '../trips/presentation/logic/realtime_trip_cubit/realtime_trip_cubit.dart';
import '../trips/presentation/logic/trip_cubit/trip_cubit.dart';
import '../trips/presentation/views/all_trips_view.dart';
import 'custom_bottom_nav_bar.dart';

class ClientBottomNavBarView extends StatefulWidget {
  const ClientBottomNavBarView({super.key});

  @override
  State<ClientBottomNavBarView> createState() => _ClientBottomNavBarViewState();
}

class _ClientBottomNavBarViewState extends State<ClientBottomNavBarView> {
  int currentIndex = 0;

  List<Widget> _buildIndexedStackChildren() {
    return [
      BlocProvider(
        create: (context) => RealTimeTripCubit(getIt())..connect(),
        child: const ClientDashboardView(),
      ),
      BlocProvider(
        create: (context) =>
            (TripCubit(getIt())..getAllTrips(userId: AppConstants.kUserId)),
        child: AllTripsView(userId: AppConstants.kUserId),
      ),
      BlocProvider(
        create: (context) =>
            (UserCubit(getIt())..getUserDetails(AppConstants.kUserId)),
        child: const ClientProfileDetailsView(),
      ),
      const SettingsView(),
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
          onTabTapped: (index) {
            setState(() => currentIndex = index);
          },
        ),
      ),
    );
  }
}
