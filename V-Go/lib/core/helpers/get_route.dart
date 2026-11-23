import '../cache/cache_helper.dart';
import '../routing/routes.dart';
import '../utils/app_constants.dart';
import 'extensions.dart';

/// Riders whose gender isn't confirmed yet must pick it before reaching the app.
bool needsGenderConfirmation() =>
    AppConstants.kRole == UserRole.client.capitalized &&
    !CacheHelper.getBool(AppConstants.genderConfirmed);

String getRoute() {
  if (needsGenderConfirmation()) {
    return Routes.genderGateViewRoute;
  }
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
