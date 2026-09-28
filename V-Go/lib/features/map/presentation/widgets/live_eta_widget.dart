import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/helpers/geo_utils.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../logic/map_bloc/map_bloc.dart';
import '../logic/map_bloc/map_state.dart';

/// Live "arrives in X min • Y km" line for an active trip, driven by the
/// captain's live location (MapState.driverRemaining*). Counts down as the
/// captain moves; [toPickup] picks the wording for each leg.
///
/// Falls back to a straight-line estimate when the captain's road route isn't
/// known yet (e.g. before his first live GPS tick).
class LiveEtaWidget extends StatelessWidget {
  const LiveEtaWidget({super.key, required this.toPickup});

  final bool toPickup;

  // Rough scooter speed in town, only for the straight-line fallback.
  static const double _fallbackMetersPerSecond = 6.5;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapBloc, MapState>(
      buildWhen: (p, c) =>
          p.driverRemainingMeters != c.driverRemainingMeters ||
          p.driverRemainingSeconds != c.driverRemainingSeconds ||
          p.driverLocation != c.driverLocation,
      builder: (context, s) {
        var meters = s.driverRemainingMeters;
        var seconds = s.driverRemainingSeconds;
        final target = toPickup ? s.fromLocation : s.toLocation;
        if (meters == null && s.driverLocation != null && target != null) {
          meters = GeoUtils.haversine(
            LatLng(s.driverLocation!.latitude, s.driverLocation!.longitude),
            LatLng(target.latitude, target.longitude),
          );
        }
        if (meters == null) return const SizedBox.shrink();
        seconds ??= meters / _fallbackMetersPerSecond;

        final arrived = meters < 40;
        final label = arrived
            ? (toPickup ? 'الكابتن وصل تقريباً' : 'على وشك الوصول')
            : '${toPickup ? 'الكابتن يصل خلال' : 'الوصول خلال'} '
                  '${_minutes(seconds)}';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.lightWhite,
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, color: AppColors.primary),
              horizontalSpace(8),
              Expanded(
                child: Text(
                  label,
                  style: AppStyle.styleMedium14.copyWith(
                    color: AppColors.white,
                  ),
                ),
              ),
              if (!arrived)
                Text(
                  _distance(meters),
                  style: AppStyle.styleMedium14.copyWith(
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _minutes(double seconds) {
    final m = (seconds / 60).ceil();
    return m <= 1 ? 'أقل من دقيقة' : '$m دقيقة';
  }

  static String _distance(double meters) => meters < 1000
      ? '${(meters / 10).round() * 10} متر'
      : '${(meters / 1000).toStringAsFixed(1)} كم';
}
