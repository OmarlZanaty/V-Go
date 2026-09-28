import 'package:flutter/material.dart';

import '../../../core/theming/app_colors.dart';

/// Maps Google Routes API maneuver enums to a Material turn icon and an Arabic
/// phrase. The phrase is used both as a fallback when Google's instruction text
/// is empty and to compose spoken cues ("بعد ٣٠٠ متر، ...").
class ManeuverIcon extends StatelessWidget {
  const ManeuverIcon({
    super.key,
    required this.maneuver,
    this.size = 34,
    this.color = AppColors.black,
  });

  final String maneuver;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(iconFor(maneuver), size: size, color: color);
  }

  /// Material icon for a maneuver enum. Defaults to "straight" for unknowns so
  /// the banner always shows something sensible.
  static IconData iconFor(String maneuver) {
    switch (maneuver.toUpperCase()) {
      case 'TURN_LEFT':
      case 'RAMP_LEFT':
        return Icons.turn_left;
      case 'TURN_RIGHT':
      case 'RAMP_RIGHT':
        return Icons.turn_right;
      case 'FORK_LEFT':
        return Icons.fork_left;
      case 'FORK_RIGHT':
        return Icons.fork_right;
      case 'TURN_SLIGHT_LEFT':
        return Icons.turn_slight_left;
      case 'TURN_SLIGHT_RIGHT':
        return Icons.turn_slight_right;
      case 'TURN_SHARP_LEFT':
        return Icons.turn_sharp_left;
      case 'TURN_SHARP_RIGHT':
        return Icons.turn_sharp_right;
      case 'UTURN_LEFT':
        return Icons.u_turn_left;
      case 'UTURN_RIGHT':
        return Icons.u_turn_right;
      case 'MERGE':
        return Icons.merge;
      case 'ROUNDABOUT_LEFT':
        return Icons.roundabout_left;
      case 'ROUNDABOUT_RIGHT':
        return Icons.roundabout_right;
      case 'DEPART':
        return Icons.my_location;
      case 'DESTINATION':
      case 'DESTINATION_LEFT':
      case 'DESTINATION_RIGHT':
        return Icons.place;
      case 'STRAIGHT':
      case 'NAME_CHANGE':
      case 'KEEP_LEFT':
      case 'KEEP_RIGHT':
      default:
        return Icons.straight;
    }
  }

  /// Arabic verb phrase for a maneuver, e.g. "انعطف يميناً". Used as fallback
  /// instruction text and for building voice cues.
  static String arabicPhrase(String maneuver) {
    switch (maneuver.toUpperCase()) {
      case 'TURN_LEFT':
        return 'انعطف يساراً';
      case 'TURN_RIGHT':
        return 'انعطف يميناً';
      case 'TURN_SLIGHT_LEFT':
        return 'انعطف قليلاً يساراً';
      case 'TURN_SLIGHT_RIGHT':
        return 'انعطف قليلاً يميناً';
      case 'TURN_SHARP_LEFT':
        return 'انعطف بحدة يساراً';
      case 'TURN_SHARP_RIGHT':
        return 'انعطف بحدة يميناً';
      case 'UTURN_LEFT':
      case 'UTURN_RIGHT':
        return 'قم بالدوران للخلف';
      case 'RAMP_LEFT':
        return 'اسلك المنحدر يساراً';
      case 'RAMP_RIGHT':
        return 'اسلك المنحدر يميناً';
      case 'FORK_LEFT':
        return 'خذ التفرع الأيسر';
      case 'FORK_RIGHT':
        return 'خذ التفرع الأيمن';
      case 'KEEP_LEFT':
        return 'ابقَ يساراً';
      case 'KEEP_RIGHT':
        return 'ابقَ يميناً';
      case 'MERGE':
        return 'اندمج مع الطريق';
      case 'ROUNDABOUT_LEFT':
      case 'ROUNDABOUT_RIGHT':
        return 'ادخل الدوار';
      case 'DEPART':
        return 'ابدأ التحرك';
      case 'DESTINATION':
      case 'DESTINATION_LEFT':
      case 'DESTINATION_RIGHT':
        return 'الوصول إلى الوجهة';
      case 'STRAIGHT':
      case 'NAME_CHANGE':
      default:
        return 'استمر للأمام';
    }
  }
}
