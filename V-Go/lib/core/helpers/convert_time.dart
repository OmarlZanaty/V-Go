import 'package:intl/intl.dart';

/// Converts a [DateTime] to a human-readable string representing the time ago.
String convertTime(DateTime time) {
  final DateTime now = DateTime.now();
  final Duration difference = now.difference(time);
  if (difference.inMinutes == 0) {
    return 'الان';
  } else if (difference.inMinutes < 60) {
    return 'قبل ${difference.inMinutes} دقيقة';
  } else if (difference.inHours < 24) {
    return 'قبل ${difference.inHours} ساعة';
  } else if (difference.inDays < 365) {
    return DateFormat('dd/MM - h:mm a', 'en').format(time);
  } else {
    return DateFormat('dd/MM/yyyy - h:mm a', 'en').format(time);
  }
}

/// Converts a [DateTime] to a human-readable string representing the date and time.
String convertDate(DateTime time, {bool includeTime = false}) {
  return DateFormat(
    includeTime ? 'dd/MM/yyyy - h:mm a' : 'dd/MM/yyyy',
    'en',
  ).format(time);
}

String formatDuration(String duration) {
  final seconds = int.parse(duration.replaceAll('s', ''));
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours > 0) {
    return '$hours س${minutes > 0 ? ' و $minutes د' : ''}'.trim();
  }
  return '$minutes دقيقة';
}
