import '../models/driver_profile_model.dart';
import '../models/rating_model.dart';

abstract class ProfileRepo {
  /// The logged-in driver's profile (scooter data lives here).
  Future<DriverProfileModel> getProfile();

  /// Ratings other users have left for the logged-in driver.
  Future<List<RatingModel>> getMyRatings();

  /// Submit a support report: ensures a support chat then posts the message.
  Future<void> sendSupportReport(String content);
}
