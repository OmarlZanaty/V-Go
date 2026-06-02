import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/di/di.dart';
import '../../core/services/location_service.dart';
import '../../core/utils/logic/realtime_driver_cubit/driver_cubit.dart';
import '../../core/utils/logic/realtime_driver_cubit/driver_extension.dart';
import '../../core/utils/model/location_model.dart';
import '../../core/utils/widgets/custom_loading_widget.dart';
import '../../core/utils/widgets/custom_toastification.dart';
import 'settings_item.dart';

class EmergecySettingsItem extends StatefulWidget {
  const EmergecySettingsItem({super.key});

  @override
  State<EmergecySettingsItem> createState() => _EmergecySettingsItemState();
}

class _EmergecySettingsItemState extends State<EmergecySettingsItem> {
  bool loading = false;
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DriverCubit(getIt())..connect(),
      child: BlocConsumer<DriverCubit, DriverState>(
        listenWhen: (previous, current) => _buildAndlistenWhen(current),
        buildWhen: (previous, current) => _buildAndlistenWhen(current),
        listener: (context, state) {
          if (state.status.isSendAlertFailure) {
            setState(() {
              loading = false;
            });
            errorToast(context, 'حدث خطا', 'حاول مره اخري');
          } else if (state.status.isSendAlertSuccess) {
            setState(() {
              loading = false;
            });
            successToast(context, 'عمليه ناجحة', 'تم ارسال طلب الطوارئ');
          }
        },
        builder: (context, state) {
          return loading
              ? const CustomLoadingWidget()
              : SettingsItem(
                  title: 'ارسال حالة طواري',
                  icon: HugeIcons.strokeRoundedAlert02,
                  onTap: () {
                    infoToast(context, 'ارسال حالة طواري', 'اضغط مطولاً للارسال');
                  },
                  onLongPress: () async {
                    try {
                      setState(() {
                        loading = true;
                      });
                      final LocationService locationService = getIt();
                      final locationPermission = await locationService
                          .requestLocationPermission();
                      if (!locationPermission && context.mounted) {
                        setState(() => loading = false);
                        errorToast(context, 'إذن الموقع مرفوض', 'يرجى تفعيل إذن الوصول للموقع');
                        return;
                      }
                      final LocationModel locationModel = await locationService
                          .getCurrentLocation();
                      if (context.mounted) {
                        context.read<DriverCubit>().sendAlertToAdmin(
                          locationModel.latitude,
                          locationModel.longitude,
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        errorToast(context, 'حدث خطا', 'حاول مره اخري');
                      }
                    }
                  },
                );
        },
      ),
    );
  }

  bool _buildAndlistenWhen(DriverState state) {
    return state.status.isSendAlertFailure ||
        state.status.isSendAlertLoading ||
        state.status.isSendAlertSuccess;
  }
}
