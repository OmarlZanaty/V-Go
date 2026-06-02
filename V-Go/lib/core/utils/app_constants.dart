import 'package:flutter/material.dart';

import '../theming/app_colors.dart';

abstract class AppConstants {
  static const String token = "token";
  static const String refreshToken = "refreshToken";
  static const String role = "role";
  static const String gender = "gender";
  static const String userId = "userId";
  static const String fcmToken = "fcmToken";
  static const String showOnboardingBefore = "showOnboardingBefore";
  static String kUserId = "";
  static String kToken = "";
  static String kRole = "";
  static const String locationDisclosureAccepted = "locationDisclosureAccepted";
}

/// This enum have (Extension to capitalize the first letter of a string)
enum UserRole { client, accountant, driver, dispatcher, admin }

/// this enum have (Extension to capitalize the first letter of a string)(electric:1,gasoline:0)
enum ScooterType { gasoline, electric }

enum RideStatus { accepted, arrived, inProgress, completed }

List<String> tripStatus = [
  'Pending',
  'Accepted',
  'Arrived',
  'InProgress',
  'Completed',
  'Canceled',
];

Map<String, String> tripStatusTranslate = {
  'Pending': 'قيد الانتظار',
  'Accepted': 'مقبولة',
  'Arrived': 'وصل',
  'InProgress': 'قيد التنفيذ',
};

enum TripStatus { pending, accepted, arrived, inProgress, completed, canceled }

const List<String> periodOptions = [
  'اليوم',
  'اخر اسبوع',
  'اخر شهر',
  'اخر ثلاثة اشهر',
  'اخر ستة اشهر',
  'اخر سنة',
];

Color tripStatusColor(String status) {
  switch (status) {
    case 'Pending':
      return Colors.grey;
    case 'Accepted':
      return Colors.green;
    case 'Arrived':
      return AppColors.primary;
    case 'Rejected':
      return Colors.red;
    case 'Completed':
      return Colors.green;
    case 'Canceled':
      return Colors.red;
    case 'InProgress':
      return AppColors.primaryOrange;
    default:
      return Colors.grey;
  }
}
