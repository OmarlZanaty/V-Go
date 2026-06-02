// ignore_for_file: deprecated_member_use

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/cache/cache_helper.dart';
import '../../../../core/di/di.dart';
import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/logic/realtime_driver_cubit/driver_cubit.dart';
import '../../../../core/utils/logic/realtime_driver_cubit/driver_extension.dart';
import '../../../../core/utils/logic/user_cubit/user_cubit.dart';
import '../../../../core/utils/logic/user_cubit/user_state_extension.dart';
import '../../../../core/utils/model/driver_status_model.dart';
import '../../../../core/utils/widgets/custom_avatar.dart';
import '../../../../core/utils/widgets/custom_failure_widget.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_refresh_indicator.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../../trips/presentation/logic/realtime_trip_cubit/realtime_trip_cubit.dart';
import '../../../trips/presentation/logic/realtime_trip_cubit/realtime_trip_extension.dart';
import '../../../trips/presentation/widgets/client_trips_count_section.dart';
import '../../../trips/presentation/widgets/new_trips_section.dart';
import '../widgets/current_trip_item.dart';
import '../widgets/location_disclosure_dialog.dart';
import '../../../../core/helpers/location_helper.dart';

class DriverDashbord extends StatefulWidget {
  const DriverDashbord({super.key});

  @override
  State<DriverDashbord> createState() => _DriverDashbordState();
}

class _DriverDashbordState extends State<DriverDashbord> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocationDisclosure();
    });
  }

  Future<void> _checkLocationDisclosure() async {
    final isAccepted = CacheHelper.getBool(
      AppConstants.locationDisclosureAccepted,
    );
    if (!isAccepted) {
      LocationDisclosureDialog.show(
        context: context,
        onAgree: () {
          CacheHelper.setData(
            key: AppConstants.locationDisclosureAccepted,
            value: true,
          );
          _updateDriverState(
            gender:
                context.read<UserCubit>().state.userDetails?.gender ??
                "male", // Default or fetch from somewhere safe if null
            isAvailable: true,
          );
        },
        onDeny: () {
          // Keep offline or just close
        },
      );
    }
  }

  Future<void> _updateDriverState({
    required String gender,
    bool isAvailable = false,
  }) async {
    try {
      setState(() => _loading = true);
      final bool isLocationReady =
          await LocationHelper.checkLocationRequirements(context);
      if (!isLocationReady) {
        setState(() => _loading = false);
        return;
      }

      final LocationService locationService = getIt();
      final currentLocation = await locationService.getCurrentLocation();
      if (mounted) {
        context.read<DriverCubit>().updateDriverStatus(
          DriverStatusModel(
            driverId: AppConstants.kUserId,
            driverGender: gender,
            isAvailable: isAvailable,
            lat: currentLocation.latitude,
            lng: currentLocation.longitude,
          ),
        );
      }
    } catch (error) {
      setState(() => _loading = false);
      if (mounted) {
        errorToast(context, 'عملية فاشلة', 'حدث خطا اثناء تحديث حالة السائق');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: BlocListener<DriverCubit, DriverState>(
          listenWhen: (previous, current) =>
              previous.status != current.status && current.status.isConnected,
          listener: (context, driverState) {
            final userState = context.read<UserCubit>().state;
            if (userState.status.isGetUserDetailsSuccess &&
                userState.userDetails?.isAvailable == true) {
              context.read<UserCubit>().updateDriverAvailability(
                !userState.userDetails!.isAvailable!,
              );
              _updateDriverState(
                gender: userState.userDetails!.gender!,
                isAvailable: true,
              );
            }
          },
          child: BlocConsumer<UserCubit, UserState>(
            buildWhen: (previous, current) => _buildAndListenWhen(current),
            listenWhen: (previous, current) => _buildAndListenWhen(current),
            listener: (context, state) async {
              if (state.status.isGetUserDetailsSuccess) {
                if (CacheHelper.getString(AppConstants.gender) !=
                    state.userDetails!.gender) {
                  CacheHelper.setData(
                    key: AppConstants.gender,
                    value: state.userDetails!.gender,
                  );
                }
              }

              if (state.status.isGetUserDetailsSuccess &&
                  state.userDetails?.isBlocked == true) {
                errorToast(context, 'عملية فاشلة', 'تم حظرك من التطبيق');
                context.pushNamedAndRemoveUntil(
                  Routes.accountTypeViewRoute,
                  predicate: (route) => false,
                );
              }
            },
            builder: (context, state) {
              if (state.status.isGetUserDetailsSuccess) {
                return SafeArea(
                  child: CustomRefreshIndicator(
                    onRefresh: () async {
                      context.read<UserCubit>().getUserDetails(
                        AppConstants.kUserId,
                        isDriver: true,
                      );
                    },
                    child: CustomScrollView(
                      slivers: [
                        SliverFillRemaining(
                          child: Column(
                            children: [
                              verticalSpace(20),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  SlideInRight(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'مرحبا 👋',
                                          style: AppStyle.styleMedium14
                                              .copyWith(color: AppColors.white),
                                        ),
                                        verticalSpace(2),
                                        Text(
                                          state.userDetails!.name,
                                          style: AppStyle.styleMedium16
                                              .copyWith(
                                                color: AppColors.white,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SlideInLeft(
                                    child: GestureDetector(
                                      onTap: () {
                                        context.pushNamed(
                                          Routes
                                              .driverAndScooterDetailsViewRoute,
                                          arguments: state.userDetails,
                                        );
                                      },
                                      child: CustomAvatar(
                                        showOutlineBorder: true,
                                        imageUrl:
                                            state.userDetails!.profilePicture,
                                        radius: 26,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              verticalSpace(20),
                              ClientTripsCountSection(
                                tripCount: state.userDetails!.tripCount ?? 0,
                                rating:
                                    state.userDetails?.rate?.toDouble() ?? 0.0,
                              ),
                              verticalSpace(20),
                              _updateStatusButton(state),
                              const Divider(
                                color: AppColors.lightWhite,
                                endIndent: 50,
                                indent: 50,
                                height: 50,
                              ),
                              BlocBuilder<RealTimeTripCubit, RealTimeTripState>(
                                buildWhen: (previous, current) {
                                  return current
                                          .status
                                          .isNewRequestedTripsForDriver ||
                                      current.status.isCurrentTripReceived;
                                },
                                builder: (context, state) {
                                  if (state.currentTrip != null) {
                                    return CurrentTripItem(
                                      currentTrip: state.currentTrip!,
                                      atClientSide: false,
                                    );
                                  }
                                  return const Expanded(
                                    child: NewTripsSection(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else if (state.status.isGetUserDetailsFailure) {
                return CustomRefreshIndicator(
                  onRefresh: () async {
                    context.read<UserCubit>().getUserDetails(
                      AppConstants.kUserId,
                      isDriver: true,
                    );
                  },
                  child: ListView(
                    children: [
                      SizedBox(
                        height: 0.8.sh,
                        child: CustomFailureWidget(text: state.errorMessage),
                      ),
                    ],
                  ),
                );
              }
              return const CustomLoadingWidget();
            },
          ),
        ),
      ),
    );
  }

  FadeIn _updateStatusButton(UserState state) {
    return FadeIn(
      delay: const Duration(milliseconds: 200),
      child: BlocListener<DriverCubit, DriverState>(
        listenWhen: (previous, current) => _listenDriverStatusWhen(current),
        listener: (context, driverState) {
          if (driverState.status.isUpdateStatusSuccess) {
            setState(() => _loading = false);
            context.read<UserCubit>().updateDriverAvailability(
              !state.userDetails!.isAvailable!,
            );
          } else if (driverState.status.isUpdateStatusFailure) {
            setState(() => _loading = false);
            errorToast(
              context,
              'عملية فاشلة',
              'حدث خطا اثناء تحديث حالة السائق',
            );
          }
        },
        child: _loading
            ? const CustomLoadingWidget()
            : InkWell(
                onTap: () {
                  final isAccepted = CacheHelper.getBool(
                    AppConstants.locationDisclosureAccepted,
                  );
                  if (!isAccepted) {
                    LocationDisclosureDialog.show(
                      context: context,
                      onAgree: () {
                        CacheHelper.setData(
                          key: AppConstants.locationDisclosureAccepted,
                          value: true,
                        );
                        _updateDriverState(
                          gender: state.userDetails!.gender!,
                          isAvailable: !state.userDetails!.isAvailable!,
                        );
                      },
                      onDeny: () {},
                    );
                  } else {
                    _updateDriverState(
                      gender: state.userDetails!.gender!,
                      isAvailable: !state.userDetails!.isAvailable!,
                    );
                  }
                },
                borderRadius: const BorderRadius.all(Radius.circular(50)),
                child: Container(
                  padding: const EdgeInsets.only(
                    top: 11,
                    left: 10,
                    right: 18,
                    bottom: 11,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.lightWhite,
                    borderRadius: BorderRadius.all(Radius.circular(50)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          state.userDetails!.isAvailable!
                              ? 'متاح الان'
                              : 'غير متاح الان',
                          style: AppStyle.styleMedium16.copyWith(
                            color: state.userDetails!.isAvailable!
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ),
                      Image.asset(
                        state.userDetails!.isAvailable!
                            ? 'assets/images/checked.png'
                            : 'assets/images/close.png',
                        width: 38,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  bool _buildAndListenWhen(UserState state) {
    return state.status.isGetUserDetailsLoading ||
        state.status.isGetUserDetailsSuccess ||
        state.status.isGetUserDetailsFailure;
  }

  bool _listenDriverStatusWhen(DriverState state) {
    return state.status.isUpdateStatusLoading ||
        state.status.isUpdateStatusSuccess ||
        state.status.isUpdateStatusFailure;
  }
}
