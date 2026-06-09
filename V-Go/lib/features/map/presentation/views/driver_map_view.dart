// ignore_for_file: prefer_foreach

import 'dart:async';
import 'dart:developer';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/set_map_style.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/logic/rating_cubit/rating_cubit.dart';
import '../../../../core/utils/model/send_rating_model.dart';
import '../../../../core/utils/widgets/app_bar_leading.dart';
import '../../../../core/utils/widgets/custom_avatar.dart';
import '../../../../core/utils/widgets/custom_button.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../../trips/data/model/new_trip_requested_for_driver_model.dart';
import '../../../trips/presentation/logic/realtime_trip_cubit/realtime_trip_cubit.dart';
import '../../../trips/presentation/logic/realtime_trip_cubit/realtime_trip_extension.dart';
import '../../../trips/presentation/widgets/rating_bar_section.dart';
import '../logic/map_bloc/map_bloc.dart';
import '../logic/map_bloc/map_event.dart';
import '../logic/map_bloc/map_state.dart';
import '../widgets/trip_duration_widget.dart';

class DriverMapView extends StatefulWidget {
  const DriverMapView({required this.requestedTrip, super.key});
  final NewTripRequestedForDriverModel requestedTrip;

  @override
  State<DriverMapView> createState() => _DriverMapViewState();
}

class _DriverMapViewState extends State<DriverMapView> {
  final Completer<GoogleMapController> _controller = Completer();
  GoogleMapController? mapController;

  late CameraPosition initPos;

  @override
  void initState() {
    super.initState();
    initPos = CameraPosition(
      target: LatLng(
        widget.requestedTrip.startLocation.lat,
        widget.requestedTrip.startLocation.lng,
      ),
      zoom: 14,
    );
    context.read<MapBloc>().add(SetTrip(trip: widget.requestedTrip));
    context.read<RealTimeTripCubit>().updateTripStatus(
      widget.requestedTrip.tripStatus!,
    );
    _requestInitialRoutes();
    _initCompass();
    // Keep screen on while driver is on this map view
    WakelockPlus.enable();
  }

  void _initCompass() {
    _compassSubscription = FlutterCompass.events?.listen((event) {
      final heading = event.heading;
      if (heading != null) {
        _updateMapBearing(heading);
      }
    });
  }

  Future<void> _updateMapBearing(double heading) async {
    // 1. Threshold: Avoid jitter by only updating if change > 5°
    final diff = _currentBearing == null
        ? 360.0
        : (heading - _currentBearing!).abs();
    if (diff < 5) return;

    // 2. Manual Override: Pause auto-rotation if user touched map recently (< 5s)
    final now = DateTime.now();
    if (_lastManualInteraction != null &&
        now.difference(_lastManualInteraction!) < const Duration(seconds: 5)) {
      return;
    }

    // 3. Throttling: Max once per 200ms for fluid but efficient updates
    if (_lastCameraUpdate != null &&
        now.difference(_lastCameraUpdate!) <
            const Duration(milliseconds: 200)) {
      return;
    }

    final controller = await _controller.future;
    final tripStatus = context.read<RealTimeTripCubit>().state.tripStatus;

    // 4. Bearing Stability & Speed Check: Skip rotation if speed < 1.0
    final currentLoc = context.read<MapBloc>().state.currentLocation;
    if (currentLoc == null || (currentLoc.speed ?? 0) < 1.0) {
      return;
    }

    // Manual Override Check: Pause auto-follow for 7 seconds
    if (_lastManualInteraction != null &&
        now.difference(_lastManualInteraction!) < const Duration(seconds: 7)) {
      return;
    }

    // Only rotate/follow during navigation phases
    if (tripStatus == "Accepted" || tripStatus == "InProgress") {
      try {
        _isProgrammaticMove = true;
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(currentLoc.latitude, currentLoc.longitude),
              bearing: heading,
              tilt: 45,
              zoom: 17.5,
            ),
          ),
        );
        _currentBearing = heading;
        _lastCameraUpdate = now;
        Future.delayed(const Duration(milliseconds: 300), () {
          _isProgrammaticMove = false;
        });
      } catch (e) {
        log('Rotation failed: $e');
        _isProgrammaticMove = false;
      }
    }
  }

  @override
  void dispose() {
    // Restore normal screen power management when leaving this view
    _compassSubscription?.cancel();
    WakelockPlus.disable();
    mapController?.dispose();
    super.dispose();
  }

  bool _routesRequested = false;
  bool isAnimated = false;
  double rating = 0.0;

  // Auto-rotation & Compass state
  StreamSubscription<CompassEvent>? _compassSubscription;
  DateTime? _lastManualInteraction;
  double? _currentBearing;
  DateTime? _lastCameraUpdate;
  bool _isProgrammaticMove = false;

  Future<void> _requestInitialRoutes() async {
    if (_routesRequested) return;
    _routesRequested = true;

    final mapBloc = context.read<MapBloc>();

    mapBloc.add(LoadInitialLocation());

    try {
      final s = await mapBloc.stream
          .firstWhere(
            (s) =>
                s.currentLocation != null &&
                s.fromLocation != null &&
                s.toLocation != null,
          )
          .timeout(const Duration(seconds: 6), onTimeout: () => mapBloc.state);

      final current = s.currentLocation ?? mapBloc.state.currentLocation;
      final from = s.fromLocation;
      final to = s.toLocation;

      if (from == null || to == null) {
        log('No from/to available after timeout');
        return;
      }

      if (current != null) {
        mapBloc.add(CalculateDriverToPickupRoute(from: current, to: from));
      } else {
        log('still no currentLocation after LoadInitialLocation');
      }

      mapBloc.add(CalculatePickupToDestinationRoute(from: from, to: to));
    } catch (e) {
      log('requestInitialRoutes error/timeout: $e');
    }
  }

  LatLngBounds _computeBoundsForAll(
    List<List<LatLng>> allRoutes, {
    List<LatLng>? extraPoints,
  }) {
    final pts = <LatLng>[];
    for (var r in allRoutes) {
      pts.addAll(r);
    }
    if (extraPoints != null) {
      pts.addAll(extraPoints);
    }

    if (pts.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(26.0541, 32.7865),
        northeast: const LatLng(26.0541, 32.7865),
      );
    }
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Set<Marker> _buildMarkers(MapState state, String currentStatus) {
    final markers = <Marker>{};

    if (state.fromLocation != null &&
        (currentStatus == "Pending" || currentStatus == "Accepted")) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(
            state.fromLocation!.latitude,
            state.fromLocation!.longitude,
          ),
          infoWindow: const InfoWindow(title: "استلام العميل"),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }

    // Show destination marker in Pending and InProgress
    if (state.toLocation != null &&
        (currentStatus == "Pending" || currentStatus == "InProgress")) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(
            state.toLocation!.latitude,
            state.toLocation!.longitude,
          ),
          infoWindow: const InfoWindow(title: "وجهة الرحلة"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines(MapState state, String currentStatus) {
    final Set<Polyline> set = {};

    // Show driver_to_client polyline (Orange) in Pending and Accepted
    if (state.routeDriverToPickup.length > 1 &&
        (currentStatus == "Pending" || currentStatus == "Accepted")) {
      set.add(
        Polyline(
          polylineId: const PolylineId("driver_to_client"),
          points: state.routeDriverToPickup,
          color: AppColors.primaryOrange,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          width: 4,
          zIndex: 1, // تحت
        ),
      );
    }

    // Show client_to_destination polyline in Pending and InProgress
    if (state.routePickupToDestination.length > 1 &&
        (currentStatus == "Pending" || currentStatus == "InProgress")) {
      set.add(
        Polyline(
          polylineId: const PolylineId("client_to_destination"),
          points: state.routePickupToDestination,
          color: AppColors.primary,
          width: 4,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          zIndex: 2, // فوق
        ),
      );
    }
    return set;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: appBarLeading(context),
      body: MultiBlocListener(
        listeners: [
          BlocListener<RealTimeTripCubit, RealTimeTripState>(
            listenWhen: (previous, current) =>
                previous.tripStatus != current.tripStatus,
            listener: (context, state) {
              // Reset animation flag when status changes to allow map to re-focus
              setState(() => isAnimated = false);
            },
          ),
        ],
        child: BlocConsumer<MapBloc, MapState>(
          listener: (context, state) async {
            GoogleMapController controller;
            try {
              controller = await _controller.future;
            } catch (_) {
              return;
            }

            // Get current trip status to determine which routes to focus on
            final tripStatus = context
                .read<RealTimeTripCubit>()
                .state
                .tripStatus;

            // Manual Override Check: Pause auto-follow for 7 seconds
            final now = DateTime.now();
            if (_lastManualInteraction != null &&
                now.difference(_lastManualInteraction!) <
                    const Duration(seconds: 7)) {
              return;
            }

            // Navigation Flow Camera Logic
            if (tripStatus == "Accepted" || tripStatus == "InProgress") {
              if (state.currentLocation != null) {
                // Speed threshold check: Don't rotate camera if speed < 1.0
                final speed = state.currentLocation!.speed ?? 0;
                final bearing = (speed > 1.0)
                    ? (state.currentLocation!.heading ?? 0)
                    : (_currentBearing ?? 0.0);

                try {
                  _isProgrammaticMove = true;
                  await controller.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: LatLng(
                          state.currentLocation!.latitude,
                          state.currentLocation!.longitude,
                        ),
                        zoom: 17.5,
                        tilt: 45,
                        bearing: bearing,
                      ),
                    ),
                  );
                  Future.delayed(const Duration(milliseconds: 1000), () {
                    _isProgrammaticMove = false;
                  });
                } catch (e) {
                  log('Navigation camera follow failed: $e');
                  _isProgrammaticMove = false;
                }
              }
              return; // Continuous follow mode doesn't need bounds computation
            }

            if (isAnimated) return;

            // ===== BOUNDS-BASED CAMERA ANIMATION (for Pending/Overview) =====
            final hasDriverToPickup = state.routeDriverToPickup.length > 1;
            final hasPickupToDest = state.routePickupToDestination.length > 1;

            final routes = <List<LatLng>>[];
            final extraPoints = <LatLng>[];

            // During Pending: Show FULL PICTURE (Current, Pickup, Destination)
            if (tripStatus == "Pending") {
              if (state.currentLocation != null) {
                extraPoints.add(
                  LatLng(
                    state.currentLocation!.latitude,
                    state.currentLocation!.longitude,
                  ),
                );
              }
              if (state.fromLocation != null) {
                extraPoints.add(
                  LatLng(
                    state.fromLocation!.latitude,
                    state.fromLocation!.longitude,
                  ),
                );
              }
              if (state.toLocation != null) {
                extraPoints.add(
                  LatLng(
                    state.toLocation!.latitude,
                    state.toLocation!.longitude,
                  ),
                );
              }

              if (hasDriverToPickup) routes.add(state.routeDriverToPickup);
              if (hasPickupToDest) routes.add(state.routePickupToDestination);

              // Don't stop animations until we have BOTH routes calculated for a stable overview
              if (hasDriverToPickup && hasPickupToDest) {
                isAnimated = true;
              }
            }

            if (routes.isEmpty && extraPoints.isEmpty) return;

            final bounds = _computeBoundsForAll(
              routes,
              extraPoints: extraPoints,
            );

            try {
              _isProgrammaticMove = true;
              await controller.animateCamera(
                CameraUpdate.newLatLngBounds(bounds, 100),
              );
              Future.delayed(const Duration(milliseconds: 1000), () {
                _isProgrammaticMove = false;
              });
            } catch (e) {
              log('animateCamera failed: $e');
              _isProgrammaticMove = false;
            }
          },
          builder: (context, state) {
            return BlocBuilder<RealTimeTripCubit, RealTimeTripState>(
              builder: (context, realTimeTripState) {
                final currentStatus = realTimeTripState.tripStatus;

                return Stack(
                  children: [
                    GoogleMap(
                      trafficEnabled: false,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      padding: const EdgeInsets.only(top: 30),
                      zoomControlsEnabled: false,
                      initialCameraPosition: initPos,
                      polylines: _buildPolylines(state, currentStatus),
                      markers: _buildMarkers(state, currentStatus),
                      onCameraMoveStarted: () {
                        // Track manual interaction to pause auto-rotation
                        // ONLY if it wasn't triggered by our own code
                        if (!_isProgrammaticMove) {
                          _lastManualInteraction = DateTime.now();
                          log('Manual interaction detected, pausing rotation');
                        }
                      },
                      onMapCreated: (controller) {
                        if (!_controller.isCompleted) {
                          _controller.complete(controller);
                        }
                        mapController = controller;
                        setMapStyle(context, mapController!);
                      },
                    ),

                    // ===== WEAK GPS INDICATOR =====
                    if (state.currentLocation != null &&
                        (state.currentLocation!.accuracy ?? 0) > 50)
                      Positioned(
                        top: 80.h,
                        left: 20.w,
                        right: 20.w,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.gps_fixed_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'إشارة GPS ضعيفة، جاري التحسين...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    driverMapBottomSheet(state),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Positioned driverMapBottomSheet(MapState state) {
    return Positioned(
      bottom: 0,
      right: 0,
      left: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  backgroundColor: AppColors.darkGrey,
                  onPressed: () async {
                    final bloc = context.read<MapBloc>();
                    final current = bloc.state.currentLocation;
                    if (mapController != null && current != null) {
                      await mapController!.animateCamera(
                        CameraUpdate.newLatLngZoom(
                          LatLng(current.latitude, current.longitude),
                          16,
                        ),
                      );
                    }
                  },
                  child: const Icon(
                    Icons.my_location,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
              ],
            ),
            BlocBuilder<RealTimeTripCubit, RealTimeTripState>(
              buildWhen: (previous, current) => _buildWhen(current),
              builder: (context, realTimeTripState) {
                switch (realTimeTripState.tripStatus) {
                  case "Pending":
                    return approveTripWidget(state, context);
                  case "Accepted":
                    return showTripDetailsAndArrivedButton(state, context);
                  case "Arrived":
                    return arrivedTripWidget(state, context);
                  case "InProgress":
                    return inProgressTripWidget(state, context);
                  case "Completed":
                    return completedTripWidget(state, context);
                  case "Canceled":
                    return cancelledTripWidget(state, context);
                  default:
                    return const SizedBox.shrink();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget approveTripWidget(MapState state, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: baseContainer(
        child: Column(
          children: [
            baseContainerHeader(title: 'قبول الرحلة وابدأ الآن!'),
            const Divider(color: AppColors.lightWhite, height: 25),
            clientAndTripDetails(),
            verticalSpace(12),
            tripDurationWidget(state),
            const Divider(color: AppColors.lightWhite, height: 30),
            BlocConsumer<RealTimeTripCubit, RealTimeTripState>(
              listenWhen: (previous, current) =>
                  approvedTripBuildAndListenWhen(current),
              buildWhen: (previous, current) =>
                  approvedTripBuildAndListenWhen(current),
              listener: (context, realTimeState) {
                if (realTimeState.status.isTripApproveFailure) {
                  errorToast(context, 'حدث خطا', realTimeState.errorMessage);
                } else if (realTimeState.status.isTripApproveSuccess) {
                  context.read<RealTimeTripCubit>().updateTripStatus(
                    "Accepted",
                  );
                  // Reset animation so the map focuses on the route to pickup
                  setState(() => isAnimated = false);
                }
              },
              builder: (context, realTimeState) {
                return realTimeState.status.isTripApproveLoading
                    ? const CustomLoadingWidget()
                    : CustomButton(
                        text: 'قبول الرحلة',
                        onPressed: () {
                          if (state.currentLocation != null) {
                            context
                                .read<RealTimeTripCubit>()
                                .approveAndAssignDriverToTrip(
                                  widget.requestedTrip.tripId,
                                  state.currentLocation!.latitude.toString(),
                                  state.currentLocation!.longitude.toString(),
                                );
                          }
                        },
                        width: 0.4.sw,
                        height: 48,
                      );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget showTripDetailsAndArrivedButton(MapState state, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: baseContainer(
        child: Column(
          children: [
            baseContainerHeader(title: 'العميل في انتظارك، لا تتأخر!'),
            const Divider(color: AppColors.lightWhite, height: 25),
            clientAndTripDetails(),
            const Divider(color: AppColors.lightWhite, height: 30),
            BlocConsumer<RealTimeTripCubit, RealTimeTripState>(
              buildWhen: (previous, current) =>
                  arrivedDriverBuildAndListenWhen(current),
              listenWhen: (previous, current) =>
                  arrivedDriverBuildAndListenWhen(current),
              listener: (context, realTimeState) {
                if (realTimeState.status.isArrivedDriverToClientFailure) {
                  errorToast(context, 'حدث خطا', realTimeState.errorMessage);
                }
              },
              builder: (context, realTimeState) {
                return realTimeState.status.isArrivedDriverToClientLoading
                    ? const CustomLoadingWidget()
                    : CustomButton(
                        text: 'وصلت',
                        onPressed: () async {
                          context
                              .read<RealTimeTripCubit>()
                              .arrivedDriverToClient(
                                widget.requestedTrip.tripId,
                              );
                        },
                        width: 0.4.sw,
                        height: 48,
                      );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget arrivedTripWidget(MapState state, BuildContext context) {
    return BlocListener<RealTimeTripCubit, RealTimeTripState>(
      listenWhen: (p, current) => current.status.isTripPaymentUpdated,
      listener: (context, state) {
        if (state.status.isTripPaymentUpdated &&
            state.paymentStatusModel!.paymentStatus == 'Paid') {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.success,
            animType: AnimType.rightSlide,
            title: 'تم الدفع',
            desc: state.paymentStatusModel!.paymentMessage,
            titleTextStyle: AppStyle.styleMedium18.copyWith(
              color: AppColors.white,
            ),
            descTextStyle: AppStyle.styleMedium14.copyWith(
              color: AppColors.white,
            ),
            dismissOnBackKeyPress: false,
            dismissOnTouchOutside: false,
            btnOkOnPress: () {},
            btnOkText: 'حسنا',
            buttonsTextStyle: AppStyle.styleMedium14.copyWith(
              color: Colors.white,
            ),
          ).show();
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: baseContainer(
          child: Column(
            children: [
              baseContainerHeader(title: 'وصلت إلى العميل!'),
              const Divider(color: AppColors.lightWhite, height: 25),
              clientAndTripDetails(),
              const Divider(color: AppColors.lightWhite, height: 30),
              BlocConsumer<RealTimeTripCubit, RealTimeTripState>(
                listener: (context, realTimeState) {
                  if (realTimeState.status.isStartTripFailure) {
                    errorToast(context, 'حدث خطا', realTimeState.errorMessage);
                  }
                },
                listenWhen: (previous, current) => startTripBuildWhen(current),
                buildWhen: (previous, current) => startTripBuildWhen(current),
                builder: (context, realTimeState) {
                  return realTimeState.status.isStartTripLoading
                      ? const CustomLoadingWidget()
                      : CustomButton(
                          text: 'بدأ الرحلة',
                          onPressed: () async {
                            context.read<RealTimeTripCubit>().startTrip(
                              widget.requestedTrip.tripId,
                            );
                          },
                          width: 0.4.sw,
                          height: 48,
                        );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget inProgressTripWidget(MapState state, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: baseContainer(
        child: Column(
          children: [
            baseContainerHeader(title: 'الرحلة جارية!'),
            const Divider(color: AppColors.lightWhite, height: 25),
            clientAndTripDetails(),
            const Divider(color: AppColors.lightWhite, height: 30),
            BlocConsumer<RealTimeTripCubit, RealTimeTripState>(
              buildWhen: (previous, current) =>
                  endTripBuildAndListenWhen(current),
              listenWhen: (previous, current) =>
                  endTripBuildAndListenWhen(current),
              listener: (context, realTimeState) {
                if (realTimeState.status.isEndTripFailure) {
                  errorToast(context, 'حدث خطا', realTimeState.errorMessage);
                }
              },
              builder: (context, realTimeState) {
                return realTimeState.status.isEndTripLoading
                    ? const CustomLoadingWidget()
                    : CustomButton(
                        text: 'انهاء الرحلة',
                        onPressed: () async {
                          context.read<RealTimeTripCubit>().endTrip(
                            widget.requestedTrip.tripId,
                          );
                          final mapBloc = context.read<MapBloc>();

                          // منع الضغط المتكرر (اختياري)
                          if (mounted == false) return;

                          // 2) اطلب من الـ Bloc مسح routeDriverToPickup
                          mapBloc.add(ClearPickupToDestinationRoute());

                          // 3) انتظر لحد ما يتفريغ المسار (مع timeout)
                          MapState updated;
                          try {
                            updated = await mapBloc.stream
                                .firstWhere(
                                  (s) => s.routePickupToDestination.isEmpty,
                                )
                                .timeout(
                                  const Duration(seconds: 5),
                                  onTimeout: () => mapBloc.state,
                                );
                          } catch (e) {
                            // لو صار timeout او خطأ، جِب آخر حالة من الـ bloc كـ fallback
                            updated = mapBloc.state;
                            log(
                              'Waiting for ClearPickupToDestinationRoute timed out or failed: $e',
                            );
                          }
                        },
                        width: 0.4.sw,
                        height: 48,
                      );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget completedTripWidget(MapState state, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: baseContainer(
        child: Column(
          children: [
            baseContainerHeader(title: 'رحلة ناجحة! شكرًا لجهودك!'),
            const Divider(color: AppColors.lightWhite, height: 25),
            clientAndTripDetails(),
            const Divider(color: AppColors.lightWhite, height: 30),
            RatingBarSection(
              onRatingUpdate: (value) {
                setState(() {
                  rating = value;
                });
              },
            ),
            const Divider(color: AppColors.lightWhite, height: 30),
            BlocConsumer<RatingCubit, RatingState>(
              listener: (context, ratingState) {
                if (ratingState.status.isSendRatingSuccess) {
                  successToast(
                    context,
                    'عملية ناجحة',
                    'تم ارسال التقييم بنجاح',
                  );
                  context.pop();
                } else if (ratingState.status.isSendRatingFailure) {
                  errorToast(context, 'حدث خطا', ratingState.errMessage);
                }
              },
              builder: (context, ratingState) {
                return ratingState.status.isSendRatingLoading
                    ? const CustomLoadingWidget()
                    : CustomButton(
                        text: 'ارسال التقييم',
                        height: 48,
                        width: 0.45.sw,
                        onPressed: () {
                          context.read<RatingCubit>().sendRating(
                            SendRatingModel(
                              score: rating.ceil(),
                              tripId: widget.requestedTrip.tripId,
                              fromUserId: AppConstants.kUserId,
                              toUserId: widget.requestedTrip.client.clientId,
                            ),
                          );
                        },
                      );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget cancelledTripWidget(MapState state, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: baseContainer(
        child: Column(
          children: [
            baseContainerHeader(title: 'الرحلة أُلغيت'),
            const Divider(color: AppColors.lightWhite, height: 25),
            clientAndTripDetails(),
          ],
        ),
      ),
    );
  }

  Widget clientAndTripDetails() {
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: AppColors.lightWhite,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            horizontalTitleGap: 14,
            title: Text(
              widget.requestedTrip.client.name,
              overflow: TextOverflow.ellipsis,
              style: AppStyle.styleMedium16.copyWith(color: AppColors.white),
            ),
            subtitle: SelectableText(
              widget.requestedTrip.client.phoneNumber,
              style: AppStyle.styleMedium14.copyWith(
                color: AppColors.lightGrey,
              ),
              onTap: () {
                Clipboard.setData(
                  ClipboardData(text: widget.requestedTrip.client.phoneNumber),
                );
                ScaffoldMessenger.of(context).showSnackBar(
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
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
            leading: CustomAvatar(
              imageUrl: widget.requestedTrip.client.imageUrl,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 21),
                verticalSpace(2),
                Text(
                  widget.requestedTrip.client.clientRate!.toStringAsFixed(1),
                  style: AppStyle.styleMedium14.copyWith(
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        verticalSpace(14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on, color: Colors.green, size: 28),
            horizontalSpace(10),
            Expanded(
              child: Text(
                widget.requestedTrip.startLocation.address,
                style: AppStyle.styleMedium14,
              ),
            ),
          ],
        ),
        verticalSpace(8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on, color: Colors.red, size: 28),
            horizontalSpace(10),
            Expanded(
              child: Text(
                widget.requestedTrip.endLocation.address,
                style: AppStyle.styleMedium14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget baseContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 14),
      decoration: const BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.all(Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget baseContainerHeader({required String title}) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppStyle.styleMedium16)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.all(Radius.circular(50)),
          ),
          child: Text(
            '${widget.requestedTrip.price.ceil()} ج.م',
            style: AppStyle.styleMedium16.copyWith(color: AppColors.black),
          ),
        ),
      ],
    );
  }

  bool _buildWhen(RealTimeTripState state) {
    return state.status.isTripStartedForDriverReceived ||
        state.status.isDriverArrivedTripReceived ||
        state.status.isTripEndedForDriverReceived ||
        state.status.isTripCanceledReceived ||
        state.status.isTripApprovedForClientReceived;
  }

  bool arrivedDriverBuildAndListenWhen(RealTimeTripState state) {
    return state.status.isArrivedDriverToClientFailure ||
        state.status.isArrivedDriverToClientSuccess ||
        state.status.isArrivedDriverToClientLoading;
  }

  bool approvedTripBuildAndListenWhen(RealTimeTripState state) {
    return state.status.isTripApproveFailure ||
        state.status.isTripApproveSuccess ||
        state.status.isTripApproveLoading;
  }

  bool startTripBuildWhen(RealTimeTripState state) {
    return state.status.isStartTripLoading ||
        state.status.isStartTripFailure ||
        state.status.isStartTripSuccess;
  }

  bool endTripBuildAndListenWhen(RealTimeTripState state) {
    return state.status.isEndTripLoading ||
        state.status.isEndTripFailure ||
        state.status.isEndTripSuccess;
  }
}
