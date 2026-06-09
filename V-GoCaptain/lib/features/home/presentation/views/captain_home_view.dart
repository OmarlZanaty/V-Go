import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../logic/cubit/captain_home_cubit.dart';
import '../widgets/active_trip_panel.dart';
import '../widgets/incoming_trip_card.dart';

class CaptainHomeView extends StatefulWidget {
  const CaptainHomeView({super.key});

  @override
  State<CaptainHomeView> createState() => _CaptainHomeViewState();
}

class _CaptainHomeViewState extends State<CaptainHomeView> {
  @override
  void initState() {
    super.initState();
    // Center the map on the captain as soon as the screen opens (only prompts
    // for permission later, when they actually go online).
    context.read<CaptainHomeCubit>().initLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'V-Go Captain',
          style: AppStyle.title.copyWith(color: AppColors.black),
        ),
      ),
      body: BlocConsumer<CaptainHomeCubit, CaptainHomeState>(
        listenWhen: (prev, curr) =>
            curr.error != null && prev.error != curr.error,
        listener: (context, state) {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            style: ToastificationStyle.fillColored,
            title: Text(state.error!, style: AppStyle.body),
            autoCloseDuration: const Duration(seconds: 4),
            alignment: Alignment.bottomCenter,
          );
        },
        builder: (context, state) {
          return Stack(
            children: [
              // Live map background, following the captain's location.
              Positioned.fill(child: _CaptainMap(state: state)),
              // Foreground: status card on top, trip/idle content at the bottom.
              Positioned.fill(child: _Foreground(state: state)),
            ],
          );
        },
      ),
    );
  }
}

class _Foreground extends StatelessWidget {
  const _Foreground({required this.state});
  final CaptainHomeState state;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[_StatusCard(state: state)];

    if (state.hasActiveTrip) {
      // Active trip needs the full height (its layout uses a Spacer).
      children
        ..add(SizedBox(height: 20.h))
        ..add(Expanded(child: ActiveTripPanel(state: state)));
    } else {
      // Idle / incoming offer float at the bottom so the map stays visible.
      children
        ..add(const Spacer())
        ..add(
          state.offer != null
              ? IncomingTripCard(offer: state.offer!, isBusy: state.isBusy)
              : _IdleHint(state: state),
        );
    }

    return Padding(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Google map filling the screen, centered on (and following) the captain.
class _CaptainMap extends StatefulWidget {
  const _CaptainMap({required this.state});
  final CaptainHomeState state;

  @override
  State<_CaptainMap> createState() => _CaptainMapState();
}

class _CaptainMapState extends State<_CaptainMap> {
  final Completer<GoogleMapController> _controller = Completer();

  // Default center until the first GPS fix arrives.
  static const LatLng _fallback = LatLng(30.0444, 31.2357); // Cairo

  LatLng? get _latLng {
    final p = widget.state.position;
    return p == null ? null : LatLng(p.latitude, p.longitude);
  }

  @override
  void didUpdateWidget(covariant _CaptainMap old) {
    super.didUpdateWidget(old);
    final pos = widget.state.position;
    final oldPos = old.state.position;
    final moved = pos != null &&
        (oldPos == null ||
            oldPos.latitude != pos.latitude ||
            oldPos.longitude != pos.longitude);
    if (moved) _animateTo(LatLng(pos.latitude, pos.longitude));
  }

  Future<void> _animateTo(LatLng target) async {
    if (!_controller.isCompleted) return;
    final controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLng(target));
  }

  @override
  Widget build(BuildContext context) {
    final hasFix = _latLng != null;
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _latLng ?? _fallback,
        zoom: hasFix ? 15.5 : 12,
      ),
      // Blue dot only once we have a fix (which means permission is granted).
      myLocationEnabled: hasFix,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      onMapCreated: (c) {
        if (!_controller.isCompleted) _controller.complete(c);
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});
  final CaptainHomeState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CaptainHomeCubit>();
    final connecting = state.connection == CaptainConnection.connecting;
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        children: [
          Container(
            width: 14.r,
            height: 14.r,
            decoration: BoxDecoration(
              color: state.isOnline ? AppColors.success : AppColors.grey,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              connecting
                  ? 'جارٍ الاتصال...'
                  : state.isOnline
                      ? 'أنت متاح لاستقبال الرحلات'
                      : 'أنت غير متصل',
              style: AppStyle.body,
            ),
          ),
          if (connecting)
            SizedBox(
              width: 24.r,
              height: 24.r,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          else
            Switch(
              value: state.isOnline,
              activeThumbColor: AppColors.primary,
              onChanged: (v) => v ? cubit.goOnline() : cubit.goOffline(),
            ),
        ],
      ),
    );
  }
}

/// Compact bottom banner shown when idle, so the map remains the focus.
class _IdleHint extends StatelessWidget {
  const _IdleHint({required this.state});
  final CaptainHomeState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: AppColors.darkGrey,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        children: [
          if (state.isOnline)
            SizedBox(
              width: 22.r,
              height: 22.r,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          else
            Icon(Icons.nightlight_round, size: 24.r, color: AppColors.grey),
          SizedBox(width: 14.w),
          Expanded(
            child: Text(
              state.isOnline
                  ? 'جارٍ البحث عن رحلات قريبة...'
                  : 'فعّل الاتصال لبدء استقبال الرحلات',
              style: AppStyle.body,
            ),
          ),
        ],
      ),
    );
  }
}
