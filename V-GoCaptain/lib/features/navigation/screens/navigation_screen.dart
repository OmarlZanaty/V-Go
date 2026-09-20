import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/services/location_service.dart';
import '../../../core/theming/app_colors.dart';
import '../../../core/theming/app_style.dart';
import '../services/navigation_engine.dart';
import '../services/routes_api_service.dart';
import '../services/tts_service.dart';
import '../utils/distance_helper.dart';
import '../widgets/eta_bar.dart';
import '../widgets/instruction_banner.dart';
import '../widgets/maneuver_icon.dart';

/// Result returned when the navigation screen closes, so the caller knows whether
/// the captain reached the target (vs. cancelled).
enum NavExitReason { arrived, cancelled }

/// Fully in-app turn-by-turn navigation. The captain never leaves V-Go: the map,
/// route, instructions and voice all render here. Drives ONE leg (origin →
/// destination); the caller relaunches it for the next leg.
class NavigationScreen extends StatefulWidget {
  const NavigationScreen({
    super.key,
    required this.origin,
    required this.destination,
    required this.destinationName,
    required this.phase, // "pickup" | "dropoff"
  });

  final LatLng origin;
  final LatLng destination;
  final String destinationName;
  final String phase;

  bool get isPickup => phase == 'pickup';

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final RoutesApiService _routes = RoutesApiService();
  final NavigationEngine _engine = NavigationEngine();
  final TtsService _tts = TtsService();
  final LocationService _location = LocationService();
  final Completer<GoogleMapController> _mapController = Completer();

  StreamSubscription<Position>? _posSub;

  NavUpdate? _update;
  LatLng _captain = const LatLng(0, 0);
  double _heading = 0;
  double _speed = 0; // m/s

  BitmapDescriptor? _arrowIcon;
  List<LatLng> _routePoints = const [];

  bool _loading = true;
  String? _error; // route load failure → retry banner
  bool _rerouting = false;
  bool _offlineWarning = false;
  bool _arrivedHandled = false;
  DateTime _lastFix = DateTime.now();
  Timer? _gpsWatchdog;

  bool get _gpsStale =>
      DateTime.now().difference(_lastFix) > const Duration(seconds: 12);

  @override
  void initState() {
    super.initState();
    _captain = widget.origin;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _tts.init();
    _arrowIcon = await _buildArrowDescriptor();
    if (mounted) setState(() {});
    await _loadRoute(from: widget.origin);
    await _startLocationStream();
    // Re-paint periodically so the "searching for GPS" banner appears if fixes stop.
    _gpsWatchdog = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() {});
    });
  }

  // ---- Route loading & rerouting -------------------------------------------

  Future<void> _loadRoute({required LatLng from}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _routes.computeRoute(
        origin: from,
        destination: widget.destination,
      );
      _engine.setRoute(result);
      setState(() {
        _routePoints = result.polyline;
        _update = _engine.update(_captain);
        _loading = false;
        _offlineWarning = false;
      });
      _frameRoute();
      _tts.resetDedupe();
      _tts.speak(widget.isPickup
          ? 'بدء التوجه إلى الراكب'
          : 'بدء التوجه إلى الوجهة');
    } catch (e) {
      // Keep the last route on screen if we have one (transient network) and
      // just warn; otherwise show the full retry state.
      if (_routePoints.isNotEmpty) {
        setState(() {
          _loading = false;
          _offlineWarning = true;
        });
      } else {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  /// Captain drifted off the route → recompute from the current position. Guarded
  /// so we don't fire overlapping requests on consecutive off-route fixes.
  Future<void> _reroute() async {
    if (_rerouting) return;
    _rerouting = true;
    _tts.speak('جارٍ إعادة حساب المسار');
    await _loadRoute(from: _captain);
    _rerouting = false;
  }

  // ---- Live location --------------------------------------------------------

  Future<void> _startLocationStream() async {
    final ok = await _location.ensurePermission();
    if (!ok) {
      if (mounted) {
        setState(() => _error = 'يلزم تفعيل صلاحية الموقع للملاحة');
      }
      return;
    }
    _posSub = _location.positionStream().listen(_onPosition);
  }

  void _onPosition(Position pos) {
    _lastFix = DateTime.now();
    _captain = LatLng(pos.latitude, pos.longitude);
    _speed = pos.speed.isFinite && pos.speed > 0 ? pos.speed : 0;
    // Use GPS heading while moving; fall back to course toward the next step.
    if (pos.heading.isFinite && _speed > 1) {
      _heading = pos.heading;
    } else if (_update?.currentStep != null) {
      _heading = DistanceHelper.bearing(_captain, _update!.currentStep!.location);
    }

    final upd = _engine.update(_captain);
    setState(() => _update = upd);

    _handleVoice(upd);
    _followCamera();

    if (upd.deviated) {
      _reroute();
      return;
    }
    if (upd.arrived && !_arrivedHandled) {
      _arrivedHandled = true;
      _onArrived();
    }
  }

  void _handleVoice(NavUpdate upd) {
    final step = upd.currentStep;
    if (step == null) return;
    final phrase = step.instruction.isNotEmpty
        ? step.instruction
        : ManeuverIcon.arabicPhrase(step.maneuver);
    switch (upd.cue) {
      case VoiceCue.far:
        _tts.speak('بعد ٣٠٠ متر، $phrase');
        break;
      case VoiceCue.near:
        _tts.speak('بعد ١٠٠ متر، $phrase');
        break;
      case VoiceCue.now:
        _tts.speak(phrase);
        break;
      case VoiceCue.none:
        break;
    }
  }

  // ---- Camera ---------------------------------------------------------------

  Future<void> _followCamera() async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _captain,
          zoom: _zoomForSpeed(_speed),
          tilt: 45, // 3D driving view
          bearing: _heading,
        ),
      ),
    );
  }

  /// Closer zoom at low speed (junctions), wider when cruising.
  double _zoomForSpeed(double speed) {
    if (speed < 4) return 18.0; // ~<14 km/h
    if (speed < 12) return 17.0; // city
    return 16.5; // highway
  }

  Future<void> _frameRoute() async {
    if (!_mapController.isCompleted || _routePoints.isEmpty) return;
    final controller = await _mapController.future;
    double minLat = _routePoints.first.latitude, maxLat = minLat;
    double minLng = _routePoints.first.longitude, maxLng = minLng;
    for (final p in _routePoints) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        70,
      ),
    );
  }

  // ---- Arrival / phase transition ------------------------------------------

  Future<void> _onArrived() async {
    await _tts.speak(widget.isPickup
        ? 'لقد وصلت إلى الراكب'
        : 'لقد وصلت إلى الوجهة');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.darkGrey,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18.r)),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 26.r),
              SizedBox(width: 10.w),
              Text(
                widget.isPickup ? 'لقد وصلت للراكب' : 'لقد وصلت للوجهة',
                style: AppStyle.title,
              ),
            ],
          ),
          content: Text(
            widget.isPickup
                ? 'يمكنك الآن استلام الراكب وبدء الرحلة.'
                : 'لقد أتممت الرحلة بنجاح.',
            style: AppStyle.body,
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop(); // close dialog
                Navigator.of(context).pop(NavExitReason.arrived);
              },
              child: Text(
                widget.isPickup ? 'بدء الرحلة' : 'تم',
                style: AppStyle.button,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCancel() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.darkGrey,
          title: Text('إنهاء الملاحة؟', style: AppStyle.title),
          content: Text('سيتم إغلاق شاشة الملاحة والعودة للرحلة.',
              style: AppStyle.body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('متابعة', style: AppStyle.body),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(NavExitReason.cancelled);
              },
              child: Text('إنهاء',
                  style: AppStyle.body.copyWith(color: AppColors.danger)),
            ),
          ],
        ),
      ),
    );
  }

  void _sos() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.darkGrey,
          title: Row(
            children: [
              Icon(Icons.sos, color: AppColors.danger, size: 24.r),
              SizedBox(width: 8.w),
              Text('طوارئ', style: AppStyle.title),
            ],
          ),
          content: Text(
            'في حال وجود خطر اتصل بالطوارئ على ١٢٢ أو بالدعم.',
            style: AppStyle.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('إغلاق', style: AppStyle.body),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Captain arrow marker (drawn at runtime, no asset needed) -------------

  Future<BitmapDescriptor> _buildArrowDescriptor() async {
    const size = 96.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // White circular halo so the arrow reads on any map background.
    final halo = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2.4, halo);

    final arrow = Paint()
      ..color = AppColors.primaryOrange
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size / 2, size * 0.18) // tip (points "up" = heading 0)
      ..lineTo(size * 0.78, size * 0.82)
      ..lineTo(size / 2, size * 0.66)
      ..lineTo(size * 0.22, size * 0.82)
      ..close();
    canvas.drawPath(path, arrow);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  Set<Marker> _markers() {
    return {
      Marker(
        markerId: const MarkerId('captain'),
        position: _captain,
        icon: _arrowIcon ?? BitmapDescriptor.defaultMarker,
        rotation: _heading,
        anchor: const Offset(0.5, 0.5),
        flat: true,
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: widget.destination,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          widget.isPickup
              ? BitmapDescriptor.hueGreen
              : BitmapDescriptor.hueOrange,
        ),
        infoWindow: InfoWindow(title: widget.destinationName),
      ),
    };
  }

  Set<Polyline> _polylines() {
    if (_routePoints.isEmpty) return const {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: _routePoints,
        color: AppColors.primary,
        width: 8,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
  }

  bool get _isNight {
    final h = DateTime.now().hour;
    return h >= 19 || h < 6;
  }

  @override
  void dispose() {
    _gpsWatchdog?.cancel();
    _posSub?.cancel();
    _tts.dispose();
    _routes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmCancel();
      },
      child: Scaffold(
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.origin,
                zoom: 16.5,
                tilt: 45,
              ),
              markers: _markers(),
              polylines: _polylines(),
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              trafficEnabled: false,
              style: _isNight ? _darkMapStyle : null,
              onMapCreated: (c) {
                if (!_mapController.isCompleted) _mapController.complete(c);
              },
            ),

            // Top: instruction banner (or route-error / loading states).
            SafeArea(
              child: Column(
                children: [
                  if (_error != null)
                    _errorBanner()
                  else if (_loading)
                    _loadingBanner()
                  else
                    InstructionBanner(update: _update),
                  if (_offlineWarning) _warningBanner(
                      'لا يوجد اتصال — يتم استخدام آخر مسار معروف'),
                  if (_gpsStale && _error == null)
                    _warningBanner('جاري البحث عن الموقع...'),
                ],
              ),
            ),

            // Bottom: ETA + actions.
            Align(
              alignment: Alignment.bottomCenter,
              child: EtaBar(
                update: _update,
                phaseLabel:
                    widget.isPickup ? 'التوجه للراكب' : 'التوجه للوجهة',
                onCancel: _confirmCancel,
                onSos: _sos,
              ),
            ),

            // Recenter button.
            Positioned(
              right: 16.w,
              bottom: 150.h,
              child: FloatingActionButton.small(
                backgroundColor: AppColors.darkGrey,
                foregroundColor: AppColors.primary,
                onPressed: _followCamera,
                child: const Icon(Icons.my_location),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingBanner() {
    return Container(
      margin: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 0),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22.r,
            height: 22.r,
            child: const CircularProgressIndicator(
                strokeWidth: 2.5, color: AppColors.black),
          ),
          SizedBox(width: 14.w),
          Text('جارٍ تحميل المسار...',
              style: AppStyle.title.copyWith(color: AppColors.black)),
        ],
      ),
    );
  }

  Widget _errorBanner() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 0),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: AppColors.darkGrey,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: AppColors.danger, width: 1.2),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.danger, size: 24.r),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(_error ?? 'تعذر تحميل المسار',
                  style: AppStyle.body),
            ),
            TextButton(
              onPressed: () => _loadRoute(from: _captain),
              child: Text('إعادة المحاولة',
                  style: AppStyle.body.copyWith(color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _warningBanner(String text) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 0),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: AppColors.primaryOrange.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: AppColors.black, size: 20.r),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(text,
                  style: AppStyle.body.copyWith(color: AppColors.black)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact dark map style for night driving (Google's standard night palette).
const String _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#212121"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#757575"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#373737"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c3c3c"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3d3d3d"}]}
]
''';
