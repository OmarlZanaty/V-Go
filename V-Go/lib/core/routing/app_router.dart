import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/accountant/presentation/views/accountant_dashboard_view.dart';
import '../../features/accountant/presentation/views/accountant_data_for_admin_view.dart';
import '../../features/accountant/presentation/views/expense_view.dart';
import '../../features/admin/presentation/views/add_dispatcher_or_accountant_view.dart';
import '../../features/admin/presentation/views/add_driver_view.dart';
import '../../features/admin/presentation/views/admin_dashboard_view.dart';
import '../../features/admin/presentation/views/all_available_drivers_view.dart';
import '../../features/admin/presentation/views/all_current_trips_view.dart';
import '../../features/admin/presentation/views/all_users_view.dart';
import '../../features/admin/presentation/views/update_user_view.dart';
import '../../features/admin/presentation/views/user_details_view.dart';
import '../../features/auth/presentation/logic/cubit/auth_cubit.dart';
import '../../features/auth/presentation/logic/phone_auth_cubit/phone_auth_cubit.dart';
import '../../features/auth/presentation/views/account_type_view.dart';
import '../../features/auth/presentation/views/change_password_view.dart';
import '../../features/auth/presentation/views/login_view.dart';
import '../../features/auth/presentation/views/phone_login_view.dart';
import '../../features/auth/presentation/views/phone_signup_view.dart';
import '../../features/auth/presentation/views/google_complete_profile_view.dart';
import '../../features/auth/presentation/views/otp_view.dart';
import '../../features/auth/presentation/views/register_view.dart';
import '../../features/auth/presentation/views/reset_password_view.dart';
import '../../features/bottom_nav_bar/client_bottom_nav_bar.dart';
import '../../features/bottom_nav_bar/driver_bottom_nav_bar.dart';
import '../../features/client/presentation/views/client_dashboard_view.dart';
import '../../features/client/presentation/views/pdf_view.dart';
import '../../features/dispatcher/presentation/views/all_dispatcher_chats_view.dart';
import '../../features/dispatcher/presentation/views/chat_view.dart';
import '../../features/dispatcher/presentation/views/dispatcher_dashboard_view.dart';
import '../../features/driver/presentation/views/driver_and_scooter_details_view.dart';
import '../../features/driver/presentation/views/driver_dashbord.dart';
import '../../features/driver/presentation/views/notification_view.dart';
import '../../features/map/presentation/logic/map_bloc/map_bloc.dart';
import '../../features/map/presentation/logic/map_bloc/map_event.dart';
import '../../features/map/presentation/views/client_map_view.dart';
import '../../features/map/presentation/views/driver_map_view.dart';
import '../../features/map/presentation/views/where_to_view.dart';
import '../../features/onboarding/onboarding_view.dart';
import '../../features/trips/data/model/new_trip_requested_for_driver_model.dart';
import '../../features/trips/data/model/trip_model.dart';
import '../../features/trips/presentation/logic/realtime_trip_cubit/realtime_trip_cubit.dart';
import '../../features/trips/presentation/logic/trip_cubit/trip_cubit.dart';
import '../../features/trips/presentation/views/all_trips_view.dart';
import '../../features/trips/presentation/views/trip_details_view.dart';
import '../cache/cache_helper.dart';
import '../di/di.dart';
import '../helpers/extensions.dart';
import '../utils/app_constants.dart';
import '../utils/logic/chat_cubit/chat_cubit.dart';
import '../utils/logic/notification_cubit/notification_cubit.dart';
import '../utils/logic/payment_cubit/payment_cubit.dart';
import '../utils/logic/rating_cubit/rating_cubit.dart';
import '../utils/logic/realtime_driver_cubit/driver_cubit.dart';
import '../utils/logic/statistics_cubit/statistics_cubit.dart';
import '../utils/logic/user_cubit/user_cubit.dart';
import '../utils/model/current_trip_model.dart';
import '../utils/model/dispatcher_chat_model.dart';
import '../utils/model/user_model.dart';
import '../utils/widgets/custom_payment_web_view.dart';
import 'routes.dart';

class AppRouter {
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.onboraingViewRoute:
        return MaterialPageRoute(builder: (_) => const OnboraingView());
      case Routes.loginViewRoute:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => AuthCubit(getIt()),
            child: const LoginView(),
          ),
        );
      case Routes.phoneLoginViewRoute:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => PhoneAuthCubit(getIt()),
            child: const PhoneLoginView(),
          ),
        );
      case Routes.phoneSignupViewRoute:
        final phone = settings.arguments as String? ?? '';
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => PhoneAuthCubit(getIt()),
            child: PhoneSignupView(phone: phone),
          ),
        );
      case Routes.googleCompleteProfileViewRoute:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => AuthCubit(getIt()),
            child: GoogleCompleteProfileView(
              idToken: args['idToken'] as String? ?? '',
              name: args['name'] as String? ?? '',
              photo: args['photo'] as String? ?? '',
            ),
          ),
        );
      case Routes.registerViewRoute:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => AuthCubit(getIt()),
            child: const RegisterView(),
          ),
        );
      case Routes.otpViewRoute:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => AuthCubit(getIt()),
            child: OtpView(
              isForgetPassword: args['isForgetPassword'],
              email: args['email'],
            ),
          ),
        );
      case Routes.resetPasswordViewRoute:
        final email = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => AuthCubit(getIt()),
            child: ResetPasswordView(email: email),
          ),
        );
      case Routes.changePasswordViewRoute:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => AuthCubit(getIt()),
            child: const ChangePasswordView(),
          ),
        );
      case Routes.adminDashboardViewRoute:
        return MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (context) =>
                    StatisticsCubit(getIt())..getAdminStatistics(),
              ),
              BlocProvider(
                create: (context) => DriverCubit(getIt())..connect(),
              ),
              BlocProvider(
                create: (context) =>
                    UserCubit(getIt())..getUserDetails(AppConstants.kUserId),
              ),
              BlocProvider(create: (context) => TripCubit(getIt())),
            ],
            child: const AdminDashboardView(),
          ),
        );
      case Routes.addDriverViewRoute:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => UserCubit(getIt()),
            child: const AddDriverView(),
          ),
        );
      case Routes.addDispatcherOrAccountantViewRoute:
        final isAccountant = settings.arguments as bool;
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => UserCubit(getIt()),
            child: AddDispatcherOrAccountantView(isAccountant: isAccountant),
          ),
        );
      case Routes.allUsersViewRoute:
        final data = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) =>
                UserCubit(getIt())..getAllUsers(role: data['role']),
            child: AllUsersView(role: data['role']),
          ),
        );
      case Routes.userDetailsViewRoute:
        final data = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) =>
                UserCubit(getIt())
                  ..getUserDetails(data['userId'], isDriver: data['isDriver']),
            child: UserDetailsView(isDriver: data['isDriver'] ?? false),
          ),
        );
      case Routes.allTripsViewRoute:
        final userId = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) =>
                (TripCubit(getIt())..getAllTrips(userId: userId)),
            child: AllTripsView(userId: userId),
          ),
        );
      case Routes.tripDetailsViewRoute:
        final trip = settings.arguments as TripModel;
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => RealTimeTripCubit(getIt())..connect(),
            child: TripDetailsView(trip: trip),
          ),
        );
      case Routes.allAvailableDriversViewRoute:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => DriverCubit(getIt())..getAvailableDrivers(),
            child: const AllAvailableDriversView(),
          ),
        );
      case Routes.dispatcherDashboardViewRoute:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) =>
                UserCubit(getIt())..getUserDetails(AppConstants.kUserId),
            child: const DispatcherDashboardView(),
          ),
        );
      case Routes.driverDashboardViewRoute:
        return MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider(create: (context) => DriverCubit(getIt())),
              BlocProvider(
                create: (context) =>
                    UserCubit(getIt())
                      ..getUserDetails(AppConstants.kUserId, isDriver: true),
              ),
              BlocProvider(
                create: (context) => RealTimeTripCubit(getIt())..connect(),
              ),
            ],
            child: const DriverDashbord(),
          ),
        );
      case Routes.updateUserViewRoute:
        final user = settings.arguments as UserModel;
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => UserCubit(getIt()),
            child: UpdateUserView(user: user),
          ),
        );
      case Routes.chatViewRoute:
        final data = settings.arguments as Map<String, dynamic>;
        final chatId = data['isClient']
            ? ''
            : (data['dispatcherChatModel'] as DispatcherChatModel).id;
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) =>
                ChatCubit(getIt(), getIt())..connect(chatId: chatId),
            child: ChatView(
              isClient: data['isClient'],
              dispatcherChatModel: data['dispatcherChatModel'],
            ),
          ),
        );
      case Routes.accountantDashboardViewRoute:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) =>
                StatisticsCubit(getIt())..getAccountantStatistics(),
            child: const AccountantDashboardView(),
          ),
        );
      case Routes.accountantDataForAdminViewRoute:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) =>
                StatisticsCubit(getIt())..getAccountantStatistics(),
            child: const AccountantDataForAdminView(),
          ),
        );
      case Routes.allCurrentTripsViewRoute:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => TripCubit(getIt())..getCurrentTrips(),
            child: const AllCurrentTripsView(),
          ),
        );
      case Routes.clientDashboardViewRoute:
        return MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (context) =>
                    UserCubit(getIt())..getUserDetails(AppConstants.kUserId),
              ),
              BlocProvider(
                create: (context) => RealTimeTripCubit(getIt())..connect(),
              ),
            ],
            child: const ClientDashboardView(),
          ),
        );
      case Routes.allDispatcherChatsViewRoute:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) =>
                ChatCubit(getIt(), getIt())
                  ..getAllDispatcherChats(dispatcherId: AppConstants.kUserId),
            child: const AllDispatcherChatsView(),
          ),
        );
      case Routes.clientMapViewRoute:
        final currentTrip = settings.arguments as CurrentTripModel?;
        return MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (context) =>
                    MapBloc(mapRepo: getIt())..add(LoadInitialLocation()),
              ),
              BlocProvider(
                create: (context) => TripCubit(getIt())..getTripKiloPrice(),
              ),
              BlocProvider(
                create: (context) => RealTimeTripCubit(getIt())..connect(),
              ),
              BlocProvider(
                lazy: false,
                create: (context) => RatingCubit(getIt())..connect(),
              ),
              BlocProvider(create: (context) => PaymentCubit(getIt())),
            ],
            child: ClientMapView(currentTrip: currentTrip),
          ),
        );
      case Routes.driverMapViewRoute:
        final trip = settings.arguments as NewTripRequestedForDriverModel;
        return MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (context) =>
                    MapBloc(mapRepo: getIt())..add(LoadInitialLocation()),
              ),
              BlocProvider(
                create: (context) => RealTimeTripCubit(getIt())..connect(),
              ),
              BlocProvider(
                lazy: false,
                create: (context) => RatingCubit(getIt())..connect(),
              ),
            ],
            child: DriverMapView(requestedTrip: trip),
          ),
        );
      case Routes.whereToViewRoute:
        final isFrom = settings.arguments as bool;
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => MapBloc(mapRepo: getIt()),
            child: WhereToView(isFrom: isFrom),
          ),
        );
      case Routes.pdfViewRoute:
        final args = settings.arguments as Map<String, String>?;
        return MaterialPageRoute(
          builder: (_) => PdfView(
            assetPath: args?['assetPath'] ?? 'assets/files/policy.pdf',
            title: args?['title'] ?? 'سياسة الخصوصية',
          ),
        );

      case Routes.clientBottomNavBarViewRoute:
        return MaterialPageRoute(
          builder: (_) => const ClientBottomNavBarView(),
        );
      case Routes.driverBottomNavBarViewRoute:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => DriverCubit(getIt())..connect,
            child: const DriverBottomNavBarView(),
          ),
        );
      case Routes.expenseViewRoute:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => StatisticsCubit(getIt())..getAllExpenses(),
            child: const ExpenseView(),
          ),
        );

      case Routes.driverAndScooterDetailsViewRoute:
        final user = settings.arguments as UserModel;
        return MaterialPageRoute(
          builder: (_) => DriverAndScooterDetailsView(user: user),
        );
      case Routes.accountTypeViewRoute:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => AuthCubit(getIt()),
            child: const AccountTypeView(),
          ),
        );
      case Routes.customPaymentWebViewRoute:
        final url = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => CustomPaymentWebView(url: url),
        );
      case Routes.notificationViewRoute:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => NotificationCubit(getIt())..getNotifications(),
            child: const NotificationView(),
          ),
        );
      default:
        return null;
    }
  }

  static String initialRoute() {
    if (!CacheHelper.getBool(AppConstants.showOnboardingBefore)) {
      return Routes.onboraingViewRoute;
    }
    if (AppConstants.kRole == UserRole.accountant.capitalized) {
      return Routes.accountantDashboardViewRoute;
    }
    if (AppConstants.kRole == UserRole.dispatcher.capitalized) {
      return Routes.dispatcherDashboardViewRoute;
    }
    if (AppConstants.kRole == UserRole.driver.capitalized) {
      return Routes.driverBottomNavBarViewRoute;
    }
    if (AppConstants.kRole == UserRole.admin.capitalized) {
      return Routes.adminDashboardViewRoute;
    }
    if (AppConstants.kRole == UserRole.client.capitalized) {
      return Routes.clientBottomNavBarViewRoute;
    }
    return Routes.accountTypeViewRoute;
  }
}
