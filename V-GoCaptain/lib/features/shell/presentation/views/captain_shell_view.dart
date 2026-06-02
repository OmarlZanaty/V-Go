import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/di.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/realtime_service.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../earnings/presentation/views/earnings_view.dart';
import '../../../home/presentation/logic/cubit/captain_home_cubit.dart';
import '../../../home/presentation/views/captain_home_view.dart';
import '../../../notifications/presentation/views/notifications_view.dart';
import '../../../profile/presentation/views/profile_view.dart';
import '../../../trips/data/repo/trip_repo.dart';
import '../../../trips/presentation/cubit/trips_cubit.dart';
import '../../../trips/presentation/views/trips_view.dart';

class CaptainShellView extends StatefulWidget {
  const CaptainShellView({super.key});

  @override
  State<CaptainShellView> createState() => _CaptainShellViewState();
}

class _CaptainShellViewState extends State<CaptainShellView> {
  int _index = 0;

  static const _tabs = [
    CaptainHomeView(),
    TripsView(),
    EarningsView(),
    NotificationsView(),
    ProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => CaptainHomeCubit(
            getIt<RealtimeService>(),
            getIt<LocationService>(),
          ),
        ),
        BlocProvider(
          create: (_) => TripsCubit(getIt<TripRepo>())..load(),
        ),
      ],
      child: Scaffold(
        body: IndexedStack(index: _index, children: _tabs),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.darkGrey,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.grey,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
            BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_outlined), label: 'رحلاتي'),
            BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_outlined),
                label: 'الأرباح'),
            BottomNavigationBarItem(
                icon: Icon(Icons.notifications_outlined), label: 'الإشعارات'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline), label: 'حسابي'),
          ],
        ),
      ),
    );
  }
}
