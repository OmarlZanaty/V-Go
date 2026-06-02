import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/helpers/calculate_distance.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/model/current_trip_model.dart';
import '../../../../core/utils/widgets/custom_avatar.dart';
import '../../../trips/presentation/logic/realtime_trip_cubit/realtime_trip_cubit.dart';
import '../logic/map_bloc/map_bloc.dart';
import '../logic/map_bloc/map_state.dart';

Widget driverDataWidget({
  CurrentTripModel? currentTrip,
  BuildContext? context,
  bool showDistance = false,
}) {
  return currentTrip != null
      ? Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: AppColors.lightWhite,
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                horizontalTitleGap: 14,
                leading: CustomAvatar(imageUrl: currentTrip.driverImageUrl),
                title: Text(
                  currentTrip.driverName,
                  style: AppStyle.styleMedium16.copyWith(
                    color: AppColors.white,
                  ),
                ),
                subtitle: SelectableText(
                  currentTrip.driverPhone,
                  style: AppStyle.styleMedium14.copyWith(
                    color: AppColors.white,
                  ),
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: currentTrip.driverPhone),
                    );
                    ScaffoldMessenger.of(context!).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        width: 180,
                        backgroundColor: AppColors.primary,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(50)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        content: Text(
                          'تم نسخ رقم الهاتف',
                          style: AppStyle.styleMedium12.copyWith(
                            color: AppColors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 22),
                    Text(
                      currentTrip.driverRate!.toStringAsFixed(1),
                      style: AppStyle.styleMedium14.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            verticalSpace(10),
            _scooterData(
              scooterLicense: currentTrip.scooterType == 'Electric'
                  ? 'لا يوجد'
                  : currentTrip.scooterLicense ?? 'لا يوجد',
              scooterType: currentTrip.scooterType ?? '',
            ),
          ],
        )
      : BlocBuilder<RealTimeTripCubit, RealTimeTripState>(
          builder: (context, state) {
            if (state.tripApprovedForClient != null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.lightWhite,
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      horizontalTitleGap: 14,
                      leading: CustomAvatar(
                        imageUrl: state.tripApprovedForClient!.driverImageUrl,
                      ),
                      title: Text(
                        state.tripApprovedForClient!.driverName,
                        style: AppStyle.styleMedium16.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                      subtitle: SelectableText(
                        state.tripApprovedForClient!.driverPhone,
                        style: AppStyle.styleMedium14.copyWith(
                          color: AppColors.white,
                        ),
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(
                              text: state.tripApprovedForClient!.driverPhone,
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              width: 180,
                              backgroundColor: AppColors.primary,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(50),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              content: Text(
                                'تم نسخ رقم الهاتف',
                                style: AppStyle.styleMedium12.copyWith(
                                  color: AppColors.black,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 22),
                          Text(
                            state.tripApprovedForClient!.driverRate!
                                .toStringAsFixed(1),
                            style: AppStyle.styleMedium14.copyWith(
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  verticalSpace(10),
                  _scooterData(
                    scooterLicense:
                        state.tripApprovedForClient!.scooterType == 'Electric'
                        ? 'لا يوجد'
                        : state.tripApprovedForClient!.scooterLicense ??
                              'لا يوجد',
                    scooterType: state.tripApprovedForClient!.scooterType,
                  ),
                  if (showDistance) ...[
                    verticalSpace(10),
                    _countDistance(state),
                  ],
                ],
              );
            }
            return Container();
          },
        );
}

ExpansionTile _scooterData({
  required String scooterType,
  required String scooterLicense,
}) {
  return ExpansionTile(
    iconColor: AppColors.primary,
    collapsedIconColor: AppColors.primary,
    tilePadding: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: Row(
      children: [
        const CircleAvatar(
          radius: 17,
          backgroundColor: AppColors.primary,
          child: Icon(
            HugeIcons.strokeRoundedScooter01,
            color: AppColors.black,
            size: 20,
          ),
        ),
        horizontalSpace(10),
        Text(
          'بيانات الاسكوتر',
          style: AppStyle.styleMedium14.copyWith(color: AppColors.white),
        ),
      ],
    ),
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: _customContainer(
                title: 'نوع الاسكوتر',
                value: scooterType == 'Electric' ? 'كهرباء' : 'بنزين',
              ),
            ),
            horizontalSpace(8),
            Expanded(
              flex: 2,
              child: _customContainer(
                title: 'رخصة الاسكوتر',
                value: scooterLicense,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

BlocBuilder<MapBloc, MapState> _countDistance(RealTimeTripState state) {
  return BlocBuilder<MapBloc, MapState>(
    builder: (context, mapState) {
      return mapState.fromLocation != null
          ? Text(
              'يبعد السائق عنك : ${calculateDistance(mapState.fromLocation!.latitude, mapState.fromLocation!.longitude, double.parse(state.tripApprovedForClient!.driverLocation!.lat), double.parse(state.tripApprovedForClient!.driverLocation!.lng))}',
              style: AppStyle.styleMedium14.copyWith(color: AppColors.white),
            )
          : const SizedBox.shrink();
    },
  );
}

Widget _customContainer({required String title, required String value}) {
  return Container(
    padding: const EdgeInsets.only(bottom: 6, top: 12, left: 14, right: 14),
    decoration: const BoxDecoration(
      color: AppColors.lightWhite,
      borderRadius: BorderRadius.all(Radius.circular(14)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppStyle.styleMedium12),
        verticalSpace(4),
        Text(
          value,
          style: AppStyle.styleMedium16.copyWith(color: AppColors.white),
        ),
      ],
    ),
  );
}
