import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/trip_fare_helper.dart';
import '../../../../core/helpers/set_map_style.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/logic/rating_cubit/rating_cubit.dart';
import '../../../../core/utils/model/current_trip_model.dart';
import '../../../../core/utils/model/location_model.dart';
import '../../../../core/utils/model/send_rating_model.dart';
import '../../../../core/utils/widgets/app_bar_leading.dart';
import '../../../../core/utils/widgets/custom_button.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../../trips/data/model/trip_model.dart';
import '../../../trips/data/model/trip_request_model.dart';
import '../../../trips/presentation/logic/realtime_trip_cubit/realtime_trip_cubit.dart';
import '../../../trips/presentation/logic/realtime_trip_cubit/realtime_trip_extension.dart';
import '../../../trips/presentation/logic/trip_cubit/trip_cubit.dart';
import '../../../trips/presentation/widgets/rating_bar_section.dart';
import '../logic/map_bloc/map_bloc.dart';
import '../logic/map_bloc/map_event.dart';
import '../logic/map_bloc/map_state.dart';
import '../widgets/arrived_driver_section.dart';
import '../widgets/payment_options_section.dart';
import '../widgets/driver_data_widget.dart';
import '../widgets/start_trip_section.dart';
import '../widgets/trip_duration_widget.dart';
import '../../../../core/helpers/location_helper.dart';

class ClientMapView extends StatefulWidget {
  const ClientMapView({this.currentTrip, super.key});
  final CurrentTripModel? currentTrip;

  @override
  State<ClientMapView> createState() => _ClientMapViewState();
}

class _ClientMapViewState extends State<ClientMapView> {
  BitmapDescriptor? _customMarkerIcon;
  BitmapDescriptor? _fakeScooterIcon;
  Offset? _etaBubblePosition;
  Timer? _cameraMoveDebounce;
  CameraPosition initpos = const CameraPosition(
    target: LatLng(26.054134995477042, 32.78656324551554),
    zoom: 15,
  );

  static final LatLngBounds egyptBounds = LatLngBounds(
    southwest: const LatLng(22.0, 25.0), // جنوب غرب مصر
    northeast: const LatLng(31.7, 36.9), // شمال شرق مصر
  );

  final Completer<GoogleMapController> completer = Completer();
  GoogleMapController? controller;
  int status = 0;
  double rating = 0.0;
  // Payment method chosen on the confirm screen, before searching: 'Cash'/'Visa'.
  String _selectedPaymentMethod = 'Cash';
  bool _isLocationPermissionChecking = true;
  bool _isLocationPermissionGranted = false;

  @override
  void initState() {
    super.initState();

    if (widget.currentTrip != null) {
      context.read<RealTimeTripCubit>().updateTripStatus(
        widget.currentTrip!.tripStatus,
      );
      status = -1;
      context.read<MapBloc>().add(SetTripForClient(trip: widget.currentTrip!));

      if (widget.currentTrip?.tripStatus == 'Pending' && status != 0) {
        context.read<MapBloc>().add(GenerateFakeScooters());
      } else if (widget.currentTrip?.tripStatus == 'InProgress') {
        context.read<MapBloc>().add(ClearFakeScooters());
      }

      if (widget.currentTrip?.tripStatus == 'InProgress') {
        final mapBloc = context.read<MapBloc>();

        Future.delayed(const Duration(milliseconds: 500), () async {
          final dest = mapBloc.state.toLocation;
          final current = mapBloc.state.currentLocation;

          if (dest != null && current != null) {
            // 1️⃣ احسب ETA الحالي من السيرفر
            final eta = await mapBloc.mapRepo
                .getEstimatedTimeOfArrivalWithDistance(current, dest);

            if (eta != null) {
              mapBloc.add(UpdateRemainingTime(eta.eta)); // ⬅️ خزّن ETA
            }

            // 2️⃣ ابدأ تتبع الوقت ومكان السيارة
            mapBloc.startEtaTracking(dest);
          }
        });
      }
    }
    _loadCustomMarker();
    _loadFakeScooterMarker();
    _checkInitialLocation();
  }

  Future<void> _checkInitialLocation() async {
    setState(() {
      _isLocationPermissionChecking = true;
    });

    final bool granted = await LocationHelper.checkLocationRequirements(
      context,
    );

    if (mounted) {
      setState(() {
        _isLocationPermissionGranted = granted;
        _isLocationPermissionChecking = false;
      });
    }
  }

  @override
  void dispose() {
    _cameraMoveDebounce?.cancel();
    controller?.dispose();
    super.dispose();
  }

  Future<void> _loadCustomMarker() async {
    _customMarkerIcon = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(45, 45)),
      'assets/images/scooter_marker.png',
    );
  }

  Future<void> _loadFakeScooterMarker() async {
    _fakeScooterIcon = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(45, 45)),
      'assets/images/scooter_image.png',
    );
  }

  Future<void> _updateEtaBubblePosition(MapState state) async {
    if (!mounted) return;
    if (controller == null || state.routePoints.isEmpty) {
      if (_etaBubblePosition != null) {
        setState(() => _etaBubblePosition = null);
      }
      return;
    }

    try {
      final midpoint = _getMidpoint(state.routePoints);
      final screenPoint = await controller!.getScreenCoordinate(midpoint);

      // تحويل من physical pixels إلى logical pixels
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final dx = screenPoint.x.toDouble() / dpr;
      final dy = screenPoint.y.toDouble() / dpr;

      // اضبط الإزاحة عشان تكون الفقاعة فوق الخط وبمنتصف العرض تقريبًا
      const bubbleWidth = 100.0; // عدّل لو بتغير تصميم الفقاعة
      const bubbleHeight = 44.0;
      final left = dx - bubbleWidth / 2;
      final top = dy - bubbleHeight - 10; // شوية مسافة فوق الخط

      setState(() {
        _etaBubblePosition = Offset(
          left.clamp(
            8.0,
            MediaQuery.of(context).size.width - 8.0 - bubbleWidth,
          ),
          top.clamp(
            8.0,
            MediaQuery.of(context).size.height - 8.0 - bubbleHeight,
          ),
        );
      });
    } catch (e) {
      log('updateEtaBubblePosition error: $e');
    }
  }

  Set<Marker> _buildMarkers(MapState state) {
    final markers = <Marker>{};
    if (state.fromLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('from'),
          position: LatLng(
            state.fromLocation!.latitude,
            state.fromLocation!.longitude,
          ),
          infoWindow: InfoWindow(
            title: 'موقع الانطلاق',
            snippet: state.fromAddress,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }

    if (state.currentLocation != null && status == 2) {
      markers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: LatLng(
            state.currentLocation!.latitude,
            state.currentLocation!.longitude,
          ),
          infoWindow: InfoWindow(
            title: 'موقعك الحالي',
            snippet: state.currentAddress,
          ),
          icon: _customMarkerIcon!,
        ),
      );
    }

    if (state.toLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('to'),
          position: LatLng(
            state.toLocation!.latitude,
            state.toLocation!.longitude,
          ),
          infoWindow: InfoWindow(title: 'الوجهة', snippet: state.toAddress),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    // Live captain marker during an active trip.
    if (state.driverLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('captain'),
          position: LatLng(
            state.driverLocation!.latitude,
            state.driverLocation!.longitude,
          ),
          infoWindow: const InfoWindow(title: 'الكابتن'),
          icon:
              _fakeScooterIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    final tripStatus = context.read<RealTimeTripCubit>().state.tripStatus;
    if (status != 0 && status != 1 && tripStatus == 'Pending') {
      for (var i = 0; i < state.fakeScooterLocations.length; i++) {
        final loc = state.fakeScooterLocations[i];
        markers.add(
          Marker(
            markerId: MarkerId('fake_scooter_$i'),
            position: LatLng(loc.latitude, loc.longitude),
            icon: _fakeScooterIcon ?? BitmapDescriptor.defaultMarker,
            anchor: const Offset(0.5, 0.5),
          ),
        );
      }
    }

    return markers;
  }

  Set<Polyline> _buildPolylines(MapState state) {
    final Set<Polyline> set = {};

    // Show a single line. Prefer the live captain route (captain → pickup, then
    // captain → destination) once it exists; otherwise the planned trip route.
    // Drawing both at once made two overlapping lines appear on the map.
    if (state.routeDriverToPickup.isNotEmpty) {
      set.add(
        Polyline(
          polylineId: const PolylineId('driverRoute'),
          points: state.routeDriverToPickup,
          color: Colors.blueAccent,
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          zIndex: 3,
        ),
      );
    } else if (state.routePoints.isNotEmpty) {
      set.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: state.routePoints,
          color: AppColors.primary,
          width: 4,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          zIndex: 2,
        ),
      );
    }

    return set;
  }

  Future<void> _setPickupToCurrent() async {
    final mapBloc = context.read<MapBloc>();
    final current = mapBloc.state.currentLocation;

    if (current == null) {
      errorToast(context, 'خطأ', 'لم يتم تحديد موقعك الحالي.');
      return;
    }
    mapBloc.add(SelectLocationFromMap(location: current, isFrom: true));

    // انتظر (بـ timeout) لحد ما يتحدّث الـ fromLocation في الـ bloc.
    final updated = await mapBloc.stream
        .firstWhere((s) => s.fromLocation != null, orElse: () => mapBloc.state)
        .timeout(const Duration(seconds: 6), onTimeout: () => mapBloc.state);

    // استخدم from من الـ bloc لو متوفر، وإلا استعمل current كـ fallback
    final from = updated.fromLocation ?? current;

    // إذا في toLocation اطلب حساب المسار، وإلا حرك الكاميرا إلى from فقط
    final to = updated.toLocation;
    if (to != null) {
      // (اختياري) امسح المسار القديم لو أردت إظهار حالة التحميل في الواجهة
      // mapBloc.add(ClearRoute());

      // اطلب حساب المسار مرة واحدة
      mapBloc.add(CalculateRoute(fromLocation: from, toLocation: to));

      // انتظر وصول routePoints (مع timeout). إذا لم تأتي نعمل fallback لاستخدام from/to
      final stateWithRoute = await mapBloc.stream
          .firstWhere(
            (s) => s.routePoints.isNotEmpty,
            orElse: () => mapBloc.state,
          )
          .timeout(const Duration(seconds: 6), onTimeout: () => mapBloc.state);

      List<LatLng> points;
      if (stateWithRoute.routePoints.isNotEmpty) {
        points = List<LatLng>.from(stateWithRoute.routePoints);
      } else {
        // fallback: استخدم from & to لعمل bounds
        points = [
          LatLng(from.latitude, from.longitude),
          LatLng(to.latitude, to.longitude),
        ];
      }

      // احسب bounds
      final bounds = _computeBounds(points);

      if (mounted) {
        // padding احتياطي — عدّله أو مرر bottomSheetKey لو عندك لقياس الـ bottom sheet
        final padding = 24.0 + MediaQuery.of(context).size.height * 0.28;
        // حرك الكاميرا بأمان
        try {
          if (controller != null) {
            await controller!.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, padding),
            );
          }
        } catch (e) {
          // fallback center + zoom
          log('newLatLngBounds failed: $e');
          final centerLat =
              points.map((p) => p.latitude).reduce((a, b) => a + b) /
              points.length;
          final centerLng =
              points.map((p) => p.longitude).reduce((a, b) => a + b) /
              points.length;
          try {
            if (controller != null) {
              await controller!.animateCamera(
                CameraUpdate.newLatLngZoom(LatLng(centerLat, centerLng), 13),
              );
            }
          } catch (e2) {
            log('fallback animateCamera failed: $e2');
          }
        }
      } else {
        // لا توجد وجهة بعد، فقط نحرك الكاميرا إلى الـ from
        try {
          if (controller != null) {
            await controller!.animateCamera(
              CameraUpdate.newLatLngZoom(
                LatLng(from.latitude, from.longitude),
                16,
              ),
            );
          }
        } catch (e) {
          log('animate to from failed: $e');
        }
      }
    }
  }

  LatLngBounds _computeBounds(List<LatLng> pts) {
    double minLat = pts.first.latitude;
    double maxLat = pts.first.latitude;
    double minLng = pts.first.longitude;
    double maxLng = pts.first.longitude;

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

  LatLng _getMidpoint(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    final midIndex = (points.length / 2).floor();
    return points[midIndex];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: appBarLeading(context),
      body: _isLocationPermissionChecking
          ? const CustomLoadingWidget()
          : !_isLocationPermissionGranted
          ? _buildPermissionDeniedState()
          : BlocBuilder<MapBloc, MapState>(
              builder: (context, state) {
                return state.currentLocation == null
                    ? const CustomLoadingWidget()
                    : Stack(
                        children: [
                          // Forward live captain location → MapBloc to move the
                          // marker + redraw the captain's route. Target is the
                          // destination once the ride is in progress, else pickup.
                          BlocListener<RealTimeTripCubit, RealTimeTripState>(
                            listenWhen: (p, c) =>
                                c.status.isDriverLocationReceived,
                            listener: (context, tripState) {
                              if (tripState.driverLat == null ||
                                  tripState.driverLng == null) {
                                return;
                              }
                              final mapBloc = context.read<MapBloc>();
                              final target = tripState.tripStatus == 'InProgress'
                                  ? mapBloc.state.toLocation
                                  : mapBloc.state.fromLocation;
                              mapBloc.add(
                                UpdateDriverLocation(
                                  driverLocation: LocationModel(
                                    latitude: tripState.driverLat!,
                                    longitude: tripState.driverLng!,
                                  ),
                                  target: target,
                                ),
                              );
                            },
                            child: const SizedBox.shrink(),
                          ),
                          GoogleMap(
                            cameraTargetBounds: CameraTargetBounds(egyptBounds),
                            minMaxZoomPreference: const MinMaxZoomPreference(
                              6,
                              18,
                            ),
                            trafficEnabled: false,
                            myLocationEnabled: true,
                            padding: const EdgeInsets.only(top: 30),
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            initialCameraPosition: initpos,
                            polylines: _buildPolylines(state),
                            markers: _buildMarkers(state),
                            onTap: (latLng) {
                              context.read<MapBloc>().add(
                                SelectLocationFromMap(
                                  location: LocationModel(
                                    latitude: latLng.latitude,
                                    longitude: latLng.longitude,
                                  ),
                                  isFrom: state.isFromFieldFocused,
                                ),
                              );
                            },
                            onCameraMove: (pos) {
                              // نتجنّب عمل update في كل فريم — نستخدم debounce
                              _cameraMoveDebounce?.cancel();
                              _cameraMoveDebounce = Timer(
                                const Duration(milliseconds: 250),
                                () {
                                  _updateEtaBubblePosition(
                                    context.read<MapBloc>().state,
                                  );
                                },
                              );
                            },
                            onCameraIdle: () {
                              _updateEtaBubblePosition(
                                context.read<MapBloc>().state,
                              );
                            },
                            onMapCreated: (map) {
                              if (!completer.isCompleted)
                                completer.complete(map);
                              controller = map;
                              setMapStyle(context, controller!);
                              if (context
                                      .read<MapBloc>()
                                      .state
                                      .currentLocation !=
                                  null) {
                                final cur = context
                                    .read<MapBloc>()
                                    .state
                                    .currentLocation!;
                                controller!.animateCamera(
                                  CameraUpdate.newLatLngZoom(
                                    LatLng(cur.latitude, cur.longitude),
                                    16,
                                  ),
                                );
                              }
                            },
                          ),

                          clientMapBottomSheet(state, status),
                        ],
                      );
              },
            ),
    );
  }

  Widget _buildPermissionDeniedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_off_outlined,
              size: 80,
              color: AppColors.primary,
            ),
            verticalSpace(20),
            Text(
              'الوصول للموقع مطلوب',
              style: AppStyle.styleBold20.copyWith(color: AppColors.white),
              textAlign: TextAlign.center,
            ),
            verticalSpace(10),
            Text(
              'لرؤية السائقين القريبين وتحديد نقطة الالتقاء، يرجى تفعيل إذن الوصول للموقع.',
              style: AppStyle.styleMedium14.copyWith(
                color: AppColors.lightGrey,
              ),
              textAlign: TextAlign.center,
            ),
            verticalSpace(30),
            CustomButton(
              text: 'تفعيل إذن الموقع',
              onPressed: _checkInitialLocation,
            ),
          ],
        ),
      ),
    );
  }

  Positioned clientMapBottomSheet(MapState state, int status) {
    return Positioned(
      bottom: 0,
      right: 0,
      left: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: BlocConsumer<RealTimeTripCubit, RealTimeTripState>(
          listenWhen: (previous, current) =>
              previous.tripStatus != current.tripStatus ||
              _buildAndLsitenWhen(current),
          buildWhen: (previous, current) =>
              previous.tripStatus != current.tripStatus ||
              _buildAndLsitenWhen(current),
          listener: (context, tripState) {
            final mapBloc = context.read<MapBloc>();

            // Recover the trip screen after an app restart / leaving the map:
            // when the server re-sends our current trip, restore the route and
            // switch out of the search view so the user can continue/end/pay it.
            if (tripState.status.isCurrentTripReceived &&
                tripState.currentTrip != null) {
              final ct = tripState.currentTrip!;
              const active = ['Pending', 'Accepted', 'Arrived', 'InProgress', 'Completed'];
              if (active.contains(ct.tripStatus)) {
                mapBloc.add(SetTripForClient(trip: ct));
                if (status != 2) setState(() => status = 2);
              }
            }

            // لما الرحلة تبدأ (InProgress) نبدأ تتبع ETA إذا في toLocation
            if (tripState.tripStatus == 'InProgress') {
              final dest = mapBloc.state.toLocation;
              if (dest != null && mapBloc.state.currentLocation != null) {
                mapBloc.startEtaTracking(dest);
              }
              setState(() => this.status = 2);
              return;
            }

            // لما الرحلة انتهت أو اتلغت، نوقف التتبع
            if (tripState.tripStatus == 'Completed' ||
                tripState.tripStatus == 'Canceled') {
              mapBloc.stopEtaTracking();
              mapBloc.add(ClearDriverLocation());
            }
            log(
              'Generating fake scooters & status: $status --- ${tripState.tripStatus}',
            );
            if (tripState.tripStatus == 'Pending' && status != 0) {
              mapBloc.add(GenerateFakeScooters());
            } else {
              mapBloc.add(ClearFakeScooters());
            }

            // لو حبيت: لما السائق يوصل (Arrived) ممكن نزود سلوك آخر
            if (tripState.tripStatus == 'Arrived') {
              // optional: stop or keep tracking depending UX
            }
            if (tripState.status.isTripStartedForClientReceived) {
              setState(() => this.status = 2);
            }
          },
          builder: (context, tripState) {
            if (status == 0) {
              return searchInputsSection(state, context);
            } else if (status == 1) {
              return showTripDetailsSection();
            } else if (tripState.tripStatus == 'Pending') {
              return waitingAssignDriverSection();
            } else if (tripState.tripStatus == 'Accepted') {
              return acceptedAssignDriverSection(context);
            } else if (tripState.tripStatus == 'Arrived') {
              return arrivedDriverSection(
                tripState,
                context,
                currentTrip: widget.currentTrip,
              );
            } else if (tripState.tripStatus == 'InProgress') {
              final remainingTime = context
                  .watch<MapBloc>()
                  .state
                  .remainingTime;
              log(
                'InProgress - remainingTime-----------------------------: $remainingTime',
              );
              return startTripSection(
                state,
                tripState,
                context,
                currentTrip: widget.currentTrip,
              );
            } else if (tripState.tripStatus == 'Completed') {
              return endTripWidgetSection(tripState, context);
            } else if (tripState.tripStatus == 'Canceled') {
              return showTripDetailsSection();
            } else {
              return const SizedBox.shrink();
            }
          },
        ),
      ),
    );
  }

  Widget searchInputsSection(MapState state, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
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
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: const BoxDecoration(
              color: AppColors.lightWhite,
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: state.isFromFieldFocused
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : null,
                    border: state.isFromFieldFocused
                        ? Border.all(color: AppColors.primary)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    onTap: () {
                      context.read<MapBloc>().add(
                        ToggleFieldFocus(isFrom: true),
                      );
                    },

                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    horizontalTitleGap: 14,
                    leading: const Icon(
                      Icons.location_on_sharp,
                      color: Colors.green,
                    ),
                    title: Text(
                      "من",
                      style: AppStyle.styleMedium12.copyWith(
                        color: AppColors.lightGrey,
                      ),
                    ),
                    subtitle: Text(
                      state.fromAddress ?? 'جاري تحديد موقعك',
                      overflow: TextOverflow.ellipsis,
                      style: AppStyle.styleMedium14.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _setPickupToCurrent,
                          icon: const Icon(
                            Icons.my_location,
                            color: AppColors.primary,
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            if (controller == null) return;
                            await changePickup(context, controller!);
                            if (context.mounted) {
                              final updated = context.read<MapBloc>().state;
                              if (updated.fromLocation == null ||
                                  controller == null) {
                                // ممكن تعطي Toast هنا لو حابب
                                return;
                              }

                              // نفّذ التحريك خارج setState — await لضمان الانتهاء لو محتاج
                              await controller!.animateCamera(
                                CameraUpdate.newLatLngZoom(
                                  LatLng(
                                    updated.fromLocation!.latitude,
                                    updated.fromLocation!.longitude,
                                  ),
                                  16,
                                ),
                              );
                              setState(() {});
                            }
                          },
                          icon: const Icon(
                            HugeIcons.strokeRoundedSearch01,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(color: AppColors.primary, height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: !state.isFromFieldFocused
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : null,
                    border: !state.isFromFieldFocused
                        ? Border.all(color: AppColors.primary)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    onTap: () {
                      context.read<MapBloc>().add(
                        ToggleFieldFocus(isFrom: false),
                      );
                    },
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    horizontalTitleGap: 14,
                    leading: const Icon(
                      Icons.location_on_sharp,
                      color: Colors.red,
                    ),
                    title: Text(
                      "الى ",
                      style: AppStyle.styleMedium12.copyWith(
                        color: AppColors.lightGrey,
                      ),
                    ),
                    subtitle: Text(
                      state.toAddress ?? 'الي اين',
                      overflow: TextOverflow.ellipsis,
                      style: AppStyle.styleMedium14.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {
                            if (controller == null) return;
                            goWhere(context, controller);
                          },
                          icon: const Icon(
                            HugeIcons.strokeRoundedSearch01,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (state.tripDuration != '') ...[
            verticalSpace(10),
            tripDurationWidget(state),
          ],

          verticalSpace(16),
          CustomButton(
            height: 50,
            text: 'طلب رحلة',
            onPressed: () {
              if (state.toLocation == null) {
                errorToast(context, 'خطأ', 'يجب تحديد نقطة الوصول');
                return;
              }
              status = 1;
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget showTripDetailsSection() {
    return BlocBuilder<MapBloc, MapState>(
      builder: (context, state) {
        if (state.distanceKm == null) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
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
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 12,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.lightWhite,
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'مسافة الرحلة',
                            style: AppStyle.styleRegular14.copyWith(
                              color: AppColors.white,
                            ),
                          ),
                          verticalSpace(4),
                          Text(
                            '${state.distanceKm!.toStringAsFixed(2)} كم',
                            style: AppStyle.styleMedium16.copyWith(
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  horizontalSpace(10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 12,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.lightWhite,
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'مدة الرحلة',
                            style: AppStyle.styleRegular14.copyWith(
                              color: AppColors.white,
                            ),
                          ),
                          verticalSpace(4),
                          Text(
                            state.tripDuration,
                            style: AppStyle.styleMedium16.copyWith(
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              verticalSpace(10),
              BlocConsumer<TripCubit, TripState>(
                listener: (context, tripState) {
                  if (tripState.status.isGetKiloPriceSuccess) {
                    final calculatedFare = calculateTripFare(
                      distanceKm: state.distanceKm!,
                      pricePerKilometer: tripState.tripPrice,
                    );
                    context.read<RealTimeTripCubit>().setTripPrice(
                      calculatedFare,
                    );
                  }
                },
                builder: (context, tripState) {
                  if (tripState.status.isGetKiloPriceSuccess) {
                    final calculatedFare = calculateTripFare(
                      distanceKm: state.distanceKm!,
                      pricePerKilometer: tripState.tripPrice,
                    );
                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.lightWhite,
                            borderRadius: BorderRadius.all(Radius.circular(14)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'سعر الرحلة : ',
                                style: AppStyle.styleRegular14.copyWith(
                                  color: AppColors.white,
                                ),
                              ),
                              horizontalSpace(4),
                              Text(
                                '${calculatedFare.ceil()} ج.م',
                                style: AppStyle.styleMedium16.copyWith(
                                  color: AppColors.white,
                                ),
                              ),
                            ],
                          ),
                        ),

                        verticalSpace(16),
                        Text('وسيلة الدفع', style: AppStyle.styleMedium14),
                        verticalSpace(8),
                        Row(
                          children: [
                            Expanded(
                              child: _payMethodChip(
                                'Cash',
                                'نقدي',
                                Icons.payments_outlined,
                              ),
                            ),
                            horizontalSpace(8),
                            Expanded(
                              child: _payMethodChip(
                                'Visa',
                                'فيزا',
                                Icons.credit_card,
                              ),
                            ),
                          ],
                        ),
                        verticalSpace(14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            BlocConsumer<RealTimeTripCubit, RealTimeTripState>(
                              buildWhen: (previous, current) =>
                                  requestTripBuildAndListenWhen(current),
                              listenWhen: (previous, current) =>
                                  requestTripBuildAndListenWhen(current),
                              listener: (context, realTimeState) {
                                if (realTimeState.status.isRequestTripFailure) {
                                  errorToast(
                                    context,
                                    'حدث خطا',
                                    realTimeState.errorMessage,
                                  );
                                } else if (realTimeState
                                    .status
                                    .isRequestTripSuccess) {
                                  setState(() {
                                    status = -1;
                                  });
                                }
                              },
                              builder: (context, realTimeState) {
                                return realTimeState.status.isRequestTripLoading
                                    ? const CustomLoadingWidget()
                                    : Expanded(
                                        child: CustomButton(
                                          text: 'موافق',
                                          onPressed: () {
                                            if (tripState
                                                .status
                                                .isGetKiloPriceSuccess) {
                                              final from =
                                                  state.fromLocation ??
                                                  state.currentLocation;
                                              final fromAddress =
                                                  state.fromAddress ??
                                                  state.currentAddress;
                                              final to = state.toLocation;

                                              if (from == null || to == null) {
                                                errorToast(
                                                  context,
                                                  "خطأ",
                                                  "لازم تختار نقطة انطلاق ووجهة قبل تأكيد الرحلة",
                                                );
                                                return;
                                              }

                                              final tripRequestModel =
                                                  TripRequestModel(
                                                    userId:
                                                        AppConstants.kUserId,
                                                    startLat: from.latitude,
                                                    startLng: from.longitude,
                                                    endLat: to.latitude,
                                                    endLng: to.longitude,
                                                    startAddress:
                                                        fromAddress ??
                                                        'غير محدد',
                                                    endAddress:
                                                        state.toAddress ??
                                                        'غير محدد',
                                                    distance:
                                                        state.distanceKm ?? 0.0,
                                                    paymentMethod:
                                                        _selectedPaymentMethod,
                                                  );
                                              context
                                                  .read<RealTimeTripCubit>()
                                                  .requestTrip(
                                                    tripRequestModel,
                                                  );
                                            }
                                          },
                                          height: 50,
                                        ),
                                      );
                              },
                            ),
                            horizontalSpace(8),
                            Expanded(
                              child: CustomButton(
                                text: 'تغيير المسار',
                                textColor: AppColors.white,
                                onPressed: () {
                                  status = 0;
                                  context
                                      .read<RealTimeTripCubit>()
                                      .updateTripStatus('Pending');
                                  setState(() {});
                                },
                                color: AppColors.primaryOrange,
                                height: 50,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  } else if (tripState.status.isGetKiloPriceFailure) {
                    return Text(
                      'حدث خطا في تحديد السعر',
                      style: AppStyle.styleMedium14.copyWith(color: Colors.red),
                    );
                  }
                  return Text(
                    'يتم تحديد السعر',
                    style: AppStyle.styleMedium14.copyWith(
                      color: AppColors.white,
                      height: 2,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget waitingAssignDriverSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 25),
            child: LinearProgressIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.lightWhite,
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
          Text(
            'جاري انتظار موافقة سائق...',
            style: AppStyle.styleMedium14.copyWith(color: AppColors.white),
          ),
          verticalSpace(5),
          Text(
            'سيتم إشعارك بمجرد قبول أحد السائقين.',
            style: AppStyle.styleMedium14.copyWith(color: AppColors.white),
          ),
          verticalSpace(20),
          cancelTripButton(),
          verticalSpace(8),
        ],
      ),
    );
  }

  Widget acceptedAssignDriverSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(
              top: 6,
              bottom: 4,
              left: 16,
              right: 16,
            ),
            decoration: const BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.all(Radius.circular(50)),
            ),
            child: Text(
              "تم قبول الرحلة والسائق في طريقه اليك",
              style: AppStyle.styleMedium12.copyWith(color: AppColors.white),
            ),
          ),
          verticalSpace(12),
          driverDataWidget(
            currentTrip: widget.currentTrip,
            context: context,
            showDistance: true,
          ),
          verticalSpace(18),
          Align(child: cancelTripButton()),
        ],
      ),
    );
  }

  Widget _payMethodChip(String value, String label, IconData icon) {
    final selected = _selectedPaymentMethod == value;
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.darkGrey,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.lightWhite,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? AppColors.black : AppColors.white,
            ),
            horizontalSpace(6),
            Text(
              label,
              style: AppStyle.styleMedium14.copyWith(
                color: selected ? AppColors.black : AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Big, clear fare display shown when the trip ends, so the client sees
  /// exactly how much to pay.
  Widget _tripPriceBanner(RealTimeTripState tripState) {
    final price = tripState.tripPrice > 0
        ? tripState.tripPrice
        : (widget.currentTrip?.price ?? 0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            'إجمالي الرحلة',
            style: AppStyle.styleMedium12.copyWith(color: AppColors.white),
          ),
          verticalSpace(4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${price.ceil()}',
                style: AppStyle.styleBold38.copyWith(color: AppColors.primary),
              ),
              horizontalSpace(6),
              Text(
                'ج.م',
                style: AppStyle.styleBold20.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget endTripWidgetSection(
    RealTimeTripState tripState,
    BuildContext context,
  ) {
    // The trip can't be finished (rated/closed) until payment is settled —
    // cash is confirmed by the captain, visa via the online checkout.
    final isPaid = tripState.paymentStatusModel?.paymentStatus == 'Paid';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(
              top: 6,
              bottom: 4,
              left: 16,
              right: 16,
            ),
            decoration: const BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.all(Radius.circular(50)),
            ),
            child: Text(
              'تمت الرحلة! شكرًا لاختيارك لنا!',
              style: AppStyle.styleMedium12.copyWith(color: AppColors.white),
            ),
          ),
          verticalSpace(12),
          _tripPriceBanner(tripState),
          verticalSpace(12),
          driverDataWidget(currentTrip: widget.currentTrip, context: context),
          // If the ride completed before the client paid, this is the only place
          // left to settle it — otherwise the trip stays "awaiting payment"
          // forever. Auto-hides once paymentStatus == 'Paid'.
          // Payment area — shows until paid, then auto-hides.
          paymentOptionsSection(
            context,
            tripState,
            currentTrip: tripState.currentTrip ?? widget.currentTrip,
          ),
          if (!isPaid) ...[
            verticalSpace(10),
            Text(
              'لا يمكن إنهاء الرحلة قبل إتمام الدفع.\nالدفع نقداً يؤكده السائق.',
              textAlign: TextAlign.center,
              style: AppStyle.styleMedium12.copyWith(color: AppColors.primary),
            ),
            verticalSpace(5),
          ] else ...[
            verticalSpace(10),
            Align(
              child: RatingBarSection(
                isDriver: false,
                onRatingUpdate: (value) {
                  setState(() {
                    rating = value;
                  });
                },
              ),
            ),
            verticalSpace(14),
            Align(
              child: BlocConsumer<RatingCubit, RatingState>(
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
                          height: 50,
                          width: 0.45.sw,
                          onPressed: () {
                            context.read<RatingCubit>().sendRating(
                              SendRatingModel(
                                score: rating.ceil(),
                                tripId:
                                    widget.currentTrip?.tripId ??
                                    tripState.tripApprovedForClient!.tripId,
                                fromUserId: AppConstants.kUserId,
                                toUserId:
                                    widget.currentTrip?.driverId ??
                                    tripState.tripApprovedForClient!.driverId,
                              ),
                            );
                          },
                        );
                },
              ),
            ),
            verticalSpace(5),
          ],
        ],
      ),
    );
  }

  bool requestTripBuildAndListenWhen(RealTimeTripState state) {
    return state.status.isRequestTripFailure ||
        state.status.isRequestTripLoading ||
        state.status.isRequestTripSuccess;
  }

  Widget cancelTripButton() {
    return BlocConsumer<RealTimeTripCubit, RealTimeTripState>(
      listener: (context, state) {
        if (state.status.isCancelTripFailure) {
          errorToast(context, 'حدث خطا', state.errorMessage);
        } else if (state.status.isCancelTripSuccess) {
          successToast(context, 'تم الغاء الرحلة', state.successMessage);
          context.read<RealTimeTripCubit>().updateTripStatus('Pending');
          setState(() {
            status = 0;
          });
        }
      },
      builder: (context, state) {
        return state.status.isCancelTripLoading
            ? const CustomLoadingWidget()
            : ElevatedButton.icon(
                onPressed: () async {
                  context.read<MapBloc>().add(ClearFakeScooters());
                  await context.read<RealTimeTripCubit>().cancelTrip(
                    tripId: widget.currentTrip?.tripId,
                  );
                },
                label: Text(
                  'إلغاء الطلب',
                  style: AppStyle.styleMedium14.copyWith(color: Colors.white),
                ),
                icon: const Icon(Icons.cancel, color: Colors.white, size: 28),

                style: ElevatedButton.styleFrom(
                  iconAlignment: IconAlignment.end,
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.zero,
                  minimumSize: Size(1.sw * 0.42, 50),

                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(50)),
                  ),
                ),
              );
      },
    );
  }

  bool _buildAndLsitenWhen(RealTimeTripState state) {
    return state.tripStatus == 'Pending' ||
        state.status.isTripStartedForClientReceived ||
        state.status.isTripApprovedForClientReceived ||
        state.status.isTripEndedForClientReceived ||
        state.status.isClientArrivedTripReceived ||
        // Rebuild the completion screen when payment settles so the lock lifts,
        // and on re-sync so a recovered trip renders correctly.
        state.status.isTripPaymentUpdated ||
        state.status.isCurrentTripReceived;
  }
}

Future<void> goWhere(
  BuildContext context,
  GoogleMapController? controller, {
  GlobalKey? bottomSheetKey,
  double extraPadding = 24.0,
}) async {
  final result = await context.pushNamed(
    Routes.whereToViewRoute,
    arguments: false,
  );

  if ((result == null || result is! TripLocationModel)) {
    return;
  }

  final mapBloc = context.read<MapBloc>();

  // 2) خزن قيمة to الحالية لتمييز التغيير لاحقاً
  final previousTo = mapBloc.state.toLocation;

  // 3) أخبر الـ bloc بالمكان المختار (isFrom = false)
  mapBloc.add(SelectPlace(result, isFrom: false));

  // 4) انتظر حتى يتضمن الـ state toLocation جديد مختلف عن السابق (أو timeout)
  final stateAfterSelect = await mapBloc.stream
      .firstWhere((s) {
        final to = s.toLocation;
        if (to == null) return false;
        if (previousTo == null) return true; // أصبح موجودًا
        // قارن الإحداثيات للتأكد من أن الـ to تغيرت فعلاً
        return (to.latitude != previousTo.latitude) ||
            (to.longitude != previousTo.longitude);
      })
      .timeout(const Duration(seconds: 6), onTimeout: () => mapBloc.state);

  // 5) اقرأ القيم الآمنة
  final to = stateAfterSelect.toLocation;
  final from =
      stateAfterSelect.fromLocation ?? stateAfterSelect.currentLocation;

  if (to == null && context.mounted) {
    // لم يتم تحديث to (ربما timeout) — نوقف أو نعرض رسالة
    errorToast(context, 'خطأ', 'لم يتم تحديث الوجهة، حاول ثانية.');
    return;
  }
  if (from == null && context.mounted) {
    errorToast(context, 'خطأ', 'لم يتم تحديد نقطة الانطلاق بعد.');
    return;
  }

  // 6) امسح المسار القديم (اختياري لكن مفيد) ثم اطلب حساب المسار

  mapBloc.add(CalculateRoute(fromLocation: from!, toLocation: to!));

  // 7) انتظر وصول routePoints (أفضل) أو timeout
  final stateWithRoute = await mapBloc.stream
      .firstWhere((s) => s.routePoints.isNotEmpty)
      .timeout(const Duration(seconds: 6), onTimeout: () => mapBloc.state);

  // 8) جهّز قائمة النقاط لبناء bounds (أولوية لِـ routePoints)
  List<LatLng> points;
  if (stateWithRoute.routePoints.isNotEmpty) {
    points = List<LatLng>.from(stateWithRoute.routePoints);
  } else {
    points = [
      LatLng(from.latitude, from.longitude),
      LatLng(to.latitude, to.longitude),
    ];
  }

  if (points.isEmpty && context.mounted) {
    errorToast(context, 'خطأ', 'لم نحصل على نقاط كافية للعرض.');
    return;
  }

  // 9) حساب LatLngBounds
  LatLngBounds computeBounds(List<LatLng> pts) {
    double minLat = pts.first.latitude;
    double maxLat = pts.first.latitude;
    double minLng = pts.first.longitude;
    double maxLng = pts.first.longitude;
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

  final bounds = computeBounds(points);

  // 10) قياس ارتفاع bottom sheet لحساب padding (إن وُفر المفتاح)
  double bottomHeight = 0;
  try {
    if (bottomSheetKey != null) {
      final box =
          bottomSheetKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) bottomHeight = box.size.height;
    }
  } catch (e) {
    log('Failed to read bottomSheet height: $e');
  }
  if (bottomHeight <= 0 && context.mounted) {
    bottomHeight = MediaQuery.of(context).size.height * 0.28; // fallback
  }
  final padding = extraPadding + bottomHeight + 12.0;

  // 11) استخدم newLatLngBounds مع padding، وإلا fallback
  try {
    if (controller != null) {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, padding),
      );
    }
  } catch (e) {
    log('newLatLngBounds failed: $e — fallback to center+zoom');
    final centerLat =
        points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final centerLng =
        points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    try {
      if (controller != null) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(centerLat, centerLng), 13),
        );
      }
    } catch (e2) {
      log('fallback animateCamera failed: $e2');
    }
  }
}

Future<void> changePickup(
  BuildContext context,
  GoogleMapController controller,
) async {
  // افتح صفحة البحث
  final result = await context.pushNamed(
    Routes.whereToViewRoute,
    arguments: true,
  );

  if (result != null && result is TripLocationModel && context.mounted) {
    // أرسل النتيجة للـ Bloc لكن دي المرة isFrom = true
    context.read<MapBloc>().add(SelectPlace(result, isFrom: true));
    // استنى لحد ما يبقى عندنا from + to
    final updated = await context
        .read<MapBloc>()
        .stream
        .firstWhere((s) => s.fromLocation != null)
        .timeout(
          const Duration(seconds: 6),
          onTimeout: () => context.read<MapBloc>().state,
        );

    // احسب الـ route من جديد
    if (updated.toLocation != null && context.mounted) {
      context.read<MapBloc>().add(
        CalculateRoute(
          fromLocation: updated.fromLocation!,
          toLocation: updated.toLocation!,
        ),
      );
    }
  }
}
