import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/logic/realtime_driver_cubit/driver_cubit.dart';
import '../../../../core/utils/logic/realtime_driver_cubit/driver_extension.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_failure_widget.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_refresh_indicator.dart';
import '../widgets/available_driver_item.dart';

class AllAvailableDriversView extends StatelessWidget {
  const AllAvailableDriversView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: 'جميع السائقين المتاحين'),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: BlocBuilder<DriverCubit, DriverState>(
          buildWhen: (previous, current) => _buildAndListenWhen(current),
          builder: (context, state) {
            if (state.status.isFetchDriversSuccess) {
              return CustomRefreshIndicator(
                onRefresh: () async {
                  context.read<DriverCubit>().getAvailableDrivers();
                },
                child: state.drivers.isNotEmpty
                    ? ListView.builder(
                        itemCount: state.drivers.length,
                        padding: const EdgeInsets.only(top: 16, bottom: 10),
                        itemBuilder: (BuildContext context, int index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AvailableDriverItem(
                              driver: state.drivers[index],
                            ),
                          );
                        },
                      )
                    : const CustomFailureWidget(text: 'لا يوجد سائقين متاحين'),
              );
            } else if (state.status.isFetchDriversFailure) {
              return CustomFailureWidget(
                text: state.errorMessage,
                onRetry: () async {
                  context.read<DriverCubit>().getAvailableDrivers();
                },
              );
            }
            return const CustomLoadingWidget();
          },
        ),
      ),
    );
  }

  bool _buildAndListenWhen(DriverState state) =>
      state.status.isFetchDriversLoading ||
      state.status.isFetchDriversSuccess ||
      state.status.isFetchDriversFailure;
}
