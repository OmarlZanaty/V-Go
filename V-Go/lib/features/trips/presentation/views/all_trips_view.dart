import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/get_trip_status.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_failure_widget.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_refresh_indicator.dart';
import '../logic/trip_cubit/trip_cubit.dart';
import '../widgets/trip_item.dart';

class AllTripsView extends StatefulWidget {
  const AllTripsView({this.userId, super.key});
  final String? userId;

  @override
  State<AllTripsView> createState() => _AllTripsViewState();
}

class _AllTripsViewState extends State<AllTripsView> {
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _allowLoadTrips = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final cubit = context.read<TripCubit>();
    if (_paginationCheck(cubit) && _allowLoadTrips) {
      _currentPage++;
      cubit.getAllTrips(
        userId: widget.userId,
        pageNumber: _currentPage,
      );
    }
  }

  bool _paginationCheck(TripCubit cubit) {
    return cubit.state.hasNextPage &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.9 &&
        _scrollController.position.userScrollDirection ==
            ScrollDirection.reverse &&
        !cubit.state.status.isGetAllTripsLoading;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(
        title: widget.userId != null
            ? (widget.userId == AppConstants.kUserId
                  ? 'جميع رحلاتي'
                  : 'جميع رحلات المستخدم')
            : 'جميع الرحلات',
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            verticalSpace(6),
            TripFilteration(
              onStatusChanged: (value) {
                setState(() {
                  _allowLoadTrips = value;
                });
              },
            ),
            verticalSpace(4),
            Expanded(
              child: BlocBuilder<TripCubit, TripState>(
                buildWhen: (previous, current) => _buildWhen(current),
                builder: (context, state) {
                  if (state.status.isGetAllTripsSuccess ||
                      (state.status.isGetAllTripsLoading &&
                          state.trips.isNotEmpty)) {
                    final trips = state.filteredTrips;
                    final bool showLoadingIndicator =
                        state.status.isGetAllTripsLoading && state.hasNextPage;

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 16, bottom: 10),
                      itemCount: trips.length + (showLoadingIndicator ? 1 : 0),
                      itemBuilder: (BuildContext context, int index) {
                        if (index == trips.length && showLoadingIndicator) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: CustomLoadingWidget(),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TripItem(
                            trip: trips[index],
                            onTap: () {
                              context.pushNamed(
                                Routes.tripDetailsViewRoute,
                                arguments: trips[index],
                              );
                            },
                          ),
                        );
                      },
                    );
                  } else if (state.status.isGetAllTripsFailure) {
                    return _allowLoadTrips
                        ? CustomRefreshIndicator(
                            onRefresh: () async {
                              await context.read<TripCubit>().getAllTrips(
                                userId: widget.userId,
                              );
                            },
                            child: ListView(
                              children: [
                                SizedBox(
                                  height: 0.8.sh,
                                  child: CustomFailureWidget(
                                    text: state.errorMessage,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView(
                            children: [
                              SizedBox(
                                height: 0.8.sh,
                                child: CustomFailureWidget(
                                  text: state.errorMessage,
                                ),
                              ),
                            ],
                          );
                  }
                  return const CustomLoadingWidget();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _buildWhen(TripState state) =>
      state.status.isGetAllTripsLoading ||
      state.status.isGetAllTripsSuccess ||
      state.status.isGetAllTripsFailure;
}

class TripFilteration extends StatefulWidget {
  const TripFilteration({required this.onStatusChanged, super.key});
  final Function(bool value) onStatusChanged;
  @override
  State<TripFilteration> createState() => _TripFilterationState();
}

class _TripFilterationState extends State<TripFilteration> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tripStatus.length + 1,
        separatorBuilder: (_, __) => horizontalSpace(6),
        itemBuilder: (context, index) {
          final label = index == 0
              ? 'الكل'
              : getTripStatus(tripStatus[index - 1]);
          return ChoiceChip(
            label: Text(
              label,
              style: AppStyle.styleMedium12.copyWith(
                color: selectedIndex == index
                    ? AppColors.black
                    : AppColors.white,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            backgroundColor: selectedIndex == index
                ? AppColors.primary
                : AppColors.darkGrey,
            checkmarkColor: selectedIndex == index
                ? AppColors.black
                : AppColors.white,
            side: const BorderSide(color: Colors.transparent),
            color: WidgetStatePropertyAll(
              selectedIndex == index ? AppColors.primary : AppColors.darkGrey,
            ),
            selected: selectedIndex == index,
            onSelected: (selected) {
              widget.onStatusChanged(index == 0);
              setState(() => selectedIndex = index);
              context.read<TripCubit>().filterTripsByStatus(
                index == 0 ? '' : tripStatus[index - 1],
              );
            },
          );
        },
      ),
    );
  }
}
