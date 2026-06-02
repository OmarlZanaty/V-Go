import '../routing/routes.dart';
import '../utils/app_constants.dart';
import 'extensions.dart';

String getRoute() {
  if (AppConstants.kRole == UserRole.accountant.capitalized) {
    return Routes.accountantDashboardViewRoute;
  } else if (AppConstants.kRole == UserRole.dispatcher.capitalized) {
    return Routes.dispatcherDashboardViewRoute;
  } else if (AppConstants.kRole == UserRole.driver.capitalized) {
    return Routes.driverBottomNavBarViewRoute;
  } else if (AppConstants.kRole == UserRole.admin.capitalized) {
    return Routes.adminDashboardViewRoute;
  } else if (AppConstants.kRole == UserRole.client.capitalized) {
    return Routes.clientBottomNavBarViewRoute;
  } else {
    return Routes.accountTypeViewRoute;
  }
}
