import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_failure_widget.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_refresh_indicator.dart';
import '../../../driver/presentation/widgets/current_trip_item.dart';
import '../../../trips/presentation/logic/trip_cubit/trip_cubit.dart';

class AllCurrentTripsView extends StatelessWidget {
  const AllCurrentTripsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: 'الرحلات الحالية'),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: BlocBuilder<TripCubit, TripState>(
          buildWhen: (previous, current) => _buildWhen(current),
          builder: (context, state) {
            if (state.status.isGetAllTripsSuccess) {
              return CustomRefreshIndicator(
                onRefresh: () async {
                  await context.read<TripCubit>().getCurrentTrips();
                },
                child: state.currentTrips.isEmpty
                    ? const CustomFailureWidget(text: 'لا يوجد رحلات حالية')
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 16, bottom: 10),
                        itemCount: state.currentTrips.length,
                        itemBuilder: (BuildContext context, int index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: CurrentTripItem(
                              currentTrip: state.currentTrips[index],
                            ),
                          );
                        },
                      ),
              );
            } else if (state.status.isGetAllTripsFailure) {
              return CustomFailureWidget(text: state.errorMessage);
            }
            return const CustomLoadingWidget();
          },
        ),
      ),
    );
  }

  bool _buildWhen(TripState state) {
    return state.status.isGetAllTripsSuccess ||
        state.status.isGetAllTripsFailure ||
        state.status.isGetAllTripsLoading;
  }
}
