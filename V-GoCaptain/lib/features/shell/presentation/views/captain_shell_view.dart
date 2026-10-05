import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/di.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/realtime_service.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../finance/data/repo/finance_repo.dart';
import '../../../finance/presentation/cubit/finance_cubit.dart';
import '../../../finance/presentation/views/finance_view.dart';
import '../../../home/presentation/logic/cubit/captain_home_cubit.dart';
import '../../../home/presentation/views/captain_home_view.dart';
import '../../../notifications/presentation/views/notifications_view.dart';
import '../../../profile/presentation/views/profile_view.dart';
import '../../../trips/data/repo/trip_repo.dart';
import '../../../trips/presentation/cubit/trips_cubit.dart';
import '../../../trips/presentation/views/trips_view.dart';
import '../../../verification/data/repo/verification_repo.dart';
import '../../../verification/presentation/cubit/verification_cubit.dart';

class CaptainShellView extends StatefulWidget {
  const CaptainShellView({super.key, this.openVerificationOnStart = false});

  final bool openVerificationOnStart;

  @override
  State<CaptainShellView> createState() => _CaptainShellViewState();
}

class _CaptainShellViewState extends State<CaptainShellView> {
  int _index = 0;

  static const _tabs = [
    CaptainHomeView(),
    TripsView(),
    FinanceView(),
    NotificationsView(),
    ProfileView(),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.openVerificationOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted)
          Navigator.of(context).pushNamed(Routes.verificationViewRoute);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => CaptainHomeCubit(
            getIt<RealtimeService>(),
            getIt<LocationService>(),
            getIt<TripRepo>(),
            getIt<FinanceRepo>(),
          ),
        ),
        BlocProvider(create: (_) => TripsCubit(getIt<TripRepo>())..load()),
        BlocProvider(
          create: (_) =>
              FinanceCubit(getIt<FinanceRepo>(), getIt<RealtimeService>())
                ..load(),
        ),
        BlocProvider(
          create: (_) => VerificationCubit(getIt<VerificationRepo>())..load(),
        ),
      ],
      child: Builder(
        builder: (context) {
          context.read<CaptainHomeCubit>().onTripCompleted = () {
            context.read<TripsCubit>().load();
            context.read<FinanceCubit>().refresh();
          };
          return _scaffold(context);
        },
      ),
    );
  }

  Widget _scaffold(BuildContext context) {
    return BlocListener<CaptainHomeCubit, CaptainHomeState>(
      listenWhen: (previous, current) =>
          previous.onlineBlock != current.onlineBlock &&
          current.onlineBlock != null,
      listener: (context, state) => _showOnlineBlockSheet(context, state),
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
              icon: Icon(Icons.home_outlined),
              label: 'الرئيسية',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              label: 'رحلاتي',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              label: 'الحسابات',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              label: 'الإشعارات',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'حسابي',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showOnlineBlockSheet(
    BuildContext context,
    CaptainHomeState state,
  ) async {
    final block = state.onlineBlock;
    if (block == null) return;
    final code = block.code ?? '';
    final action = switch (code) {
      'CASH_LIMIT' => 'سدّد المستحقات',
      'KYC_PENDING' || 'KYC_REJECTED' || 'DOCS_OVERDUE' => 'ارفع المستندات',
      'SUSPENDED' || 'BLOCKED' => 'الدعم الفني',
      _ => 'تمام',
    };
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.darkGrey,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('مش هينفع تطلع أونلاين دلوقتي', style: AppStyle.title),
            const SizedBox(height: 10),
            Text(
              block.message ?? 'راجع حالة حسابك وحاول تاني.',
              style: AppStyle.hint,
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                if (code == 'CASH_LIMIT') {
                  setState(() => _index = 2);
                } else if (code == 'KYC_PENDING' ||
                    code == 'KYC_REJECTED' ||
                    code == 'DOCS_OVERDUE') {
                  Navigator.of(context).pushNamed(Routes.verificationViewRoute);
                } else if (code == 'SUSPENDED' || code == 'BLOCKED') {
                  Navigator.of(context).pushNamed(Routes.supportViewRoute);
                }
              },
              child: Text(action, style: AppStyle.button),
            ),
          ],
        ),
      ),
    );
  }
}
