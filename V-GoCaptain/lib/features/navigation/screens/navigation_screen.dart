import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/services/location_service.dart';
import '../../../core/theming/app_colors.dart';
import '../../../core/theming/app_style.dart';
import '../services/navigation_engine.dart';
import '../services/routes_api_service.dart';
import '../services/tts_service.dart';
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
    this.initialClientLocation,
    this.clientLocationStream,
  });

  final LatLng origin;
  final LatLng destination;
  final String destinationName;
  final String phase;

  /// Rider's live GPS (pickup leg only), shown as its own marker so the
  /// captain can find a rider who isn't standing at the pin.
  final LatLng? initialClientLocation;
  final Stream<LatLng?>? clientLocationStream;

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
  StreamSubscription<LatLng?>? _clientSub;
  LatLng? _clientLive;

  /// On-screen rotation of the follow arrow (0 in heading-up mode, where the
  /// map itself turns).
  final ValueNotifier<double> _overlayRotation = ValueNotifier(0);
  static const double _mapTopPad = 170, _mapBottomPad = 120;
  static const double _followArrowSize = 44;

  NavUpdate? _update;
  LatLng _captain = const LatLng(0, 0); // raw GPS fix
  double _speed = 0; // m/s

  // What the map shows. Between GPS fixes the arrow keeps moving along the
  // route at the captain's speed (dead reckoning), so it sits where the
  // captain is NOW instead of trailing the last fix by a second or more; the
  // shown position then eases toward that prediction so a new fix never
  // makes it jump. Heading eases the same way, so the map never spins.
  LatLng _shown = const LatLng(0, 0);
  double _shownHeading = 0;
  double _targetHeading = 0;
  double _shownZoom = 17.5;
  Timer? _glideTimer;
  DateTime? _prevFixAt;

  double? _fixProgress; // route progress at the last on-route fix

  /// Route progress where the drawn line starts (the arrow's position when it
  /// was last cut); null = draw the whole route.
  double? _trimAt;
  DateTime _trimmedAt = DateTime.now();
  DateTime _fixAt = DateTime.now();
  double _fixSpeed = 0;
  double _gpsHeading = -1; // GPS course, <0 when unknown

  /// Longest we extrapolate past the last fix before waiting for a new one.
  static const double _maxPredictSeconds = 1.5;

  /// Camera follows the captain until they pan the map; the recenter button
  /// turns it back on.
  bool _following = true;

  /// false = map rotates with the direction of travel; true = north stays up.
  bool _northUp = false;

  BitmapDescriptor? _arrowIcon;
  List<LatLng> _routePoints = const [];

  bool _loading = true;
  String? _error; // route load failure → retry banner
  bool _rerouting = false;
  DateTime? _lastRerouteAt;
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
    _shown = widget.origin;
    _clientLive = widget.initialClientLocation;
    _clientSub = widget.clientLocationStream?.listen((p) {
      if (mounted) setState(() => _clientLive = p);
    });
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Keep the screen on while navigating.
    WakelockPlus.enable();
    // Voice, arrow icon, GPS and route all start together so the map is
    // usable as soon as the route arrives (speak() waits for TTS init itself).
    _tts.init();
    _buildArrowDescriptor().then((icon) {
      if (mounted) setState(() => _arrowIcon = icon);
    });
    _startLocationStream();
    await _loadRoute(from: widget.origin);
    // Re-paint periodically so the "searching for GPS" banner appears if fixes stop.
    // (Only rebuilds when the stale state actually flips.)
    var wasStale = false;
    _gpsWatchdog = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _gpsStale == wasStale) return;
      wasStale = _gpsStale;
      setState(() {});
    });
  }

  // ---- Route loading & rerouting -------------------------------------------

  /// [reroute] keeps the current instructions on screen (no loading banner,
  /// no "starting" announcement) while the new route is fetched.
  Future<void> _loadRoute({
    required LatLng from,
    double? heading,
    bool reroute = false,
  }) async {
    setState(() {
      if (!reroute) _loading = true;
      _error = null;
    });
    try {
      final result = await _routes.computeRoute(
        origin: from,
        destination: widget.destination,
        heading: heading,
        reroute: reroute,
      );
      if (!mounted) return;
      _engine.setRoute(result);
      // Measure from where the captain is now, not where the request started.
      final upd = _engine.update(_captain, speed: _speed);
      setState(() {
        _routePoints = result.polyline;
        _trimAt = null;
        _update = upd;
        _loading = false;
        _offlineWarning = false;
      });
      // Face the way the route starts right away, before the captain moves.
      _placeArrow(upd);
      _tts.resetDedupe();
      if (!reroute) {
        _tts.speak(widget.isPickup
            ? 'بدء التوجه إلى الراكب'
            : 'بدء التوجه إلى الوجهة');
      }
    } catch (e) {
      if (!mounted) return;
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
    // Cool-down: while offline every fix is "off route"; don't nag each time.
    final now = DateTime.now();
    if (_lastRerouteAt != null &&
        now.difference(_lastRerouteAt!) < const Duration(seconds: 4)) {
      return;
    }
    _lastRerouteAt = now;
    setState(() => _rerouting = true);
    _tts.speak('جارٍ إعادة حساب المسار');
    // Pass the direction of travel so the new route doesn't start with a U-turn.
    await _loadRoute(
      from: _captain,
      heading: _speed > 2.5 && _gpsHeading >= 0 ? _gpsHeading : null,
      reroute: true,
    );
    if (mounted) setState(() => _rerouting = false);
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
    _posSub = _location
        .positionStream(distanceFilter: 1, interval: const Duration(seconds: 1))
        .listen(_onPosition);
  }

  void _onPosition(Position pos) {
    final now = DateTime.now();
    // Drop a very inaccurate fix (e.g. between tall buildings) unless it's all
    // we've had for a while — it would only make the arrow jump.
    final recentGoodFix = _prevFixAt != null &&
        now.difference(_prevFixAt!) < const Duration(seconds: 5);
    if (pos.accuracy > 50 && recentGoodFix) return;

    _prevFixAt = now;
    _lastFix = now;
    _captain = LatLng(pos.latitude, pos.longitude);
    _speed = pos.speed.isFinite && pos.speed > 0 ? pos.speed : 0;
    _gpsHeading = pos.heading.isFinite && pos.heading >= 0 ? pos.heading : -1;

    final upd = _engine.update(_captain,
        accuracy: pos.accuracy, speed: _speed, heading: _gpsHeading);
    setState(() => _update = upd);

    _placeArrow(upd);

    _handleVoice(upd);

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
    var phrase = _phrase(step);
    // Two maneuvers back to back: announce both, like "turn right, then left".
    final next = upd.nextStep;
    if (next != null && upd.distanceToNext <= 80) {
      phrase = '$phrase، ثم ${_phrase(next)}';
    }
    switch (upd.cue) {
      case VoiceCue.far:
      case VoiceCue.near:
        _tts.speak('بعد ${_spokenDistance(upd.distanceToManeuver)}، $phrase');
        break;
      case VoiceCue.now:
        _tts.speak(phrase);
        break;
      case VoiceCue.none:
        break;
    }
  }

  String _phrase(NavStep step) => step.instruction.isNotEmpty
      ? step.instruction
      : ManeuverIcon.arabicPhrase(step.maneuver);

  /// "٢٥٠ متر" / "١٫٥ كيلو" — rounded the way a person would say it.
  String _spokenDistance(double meters) {
    final text = meters >= 1000
        ? '${(meters / 1000).toStringAsFixed(1).replaceAll('.0', '')} كيلو'
        : '${math.max(50, (meters / 50).round() * 50)} متر';
    const digits = '٠١٢٣٤٥٦٧٨٩';
    return text
        .replaceAll('.', '٫')
        .replaceAllMapped(RegExp('[0-9]'), (m) => digits[int.parse(m[0]!)]);
  }

  // ---- Arrow & camera -------------------------------------------------------

  /// A new fix arrived: remember where it put the captain on the route so the
  /// tick can extrapolate from it. Heading comes from the route itself while
  /// on it (stable, ignores how the phone is held), else from GPS course once
  /// really moving.
  void _placeArrow(NavUpdate upd) {
    _fixAt = DateTime.now();
    _fixSpeed = _speed;
    _fixProgress = upd.snapped != null ? _engine.progress : null;
    if (upd.snapped == null && _gpsHeading >= 0 && _speed > 2.5) {
      _targetHeading = _gpsHeading;
    }
    // ~30 fps: smooth for driving, still light on low-end phones.
    _glideTimer ??=
        Timer.periodic(const Duration(milliseconds: 33), (_) => _glideTick());
  }

  void _glideTick() {
    if (!mounted) return;
    final sinceFix =
        DateTime.now().difference(_fixAt).inMilliseconds / 1000.0;

    // Where the captain should be right now.
    LatLng target = _captain;
    double? arrowProgress;
    final base = _fixProgress;
    if (base != null) {
      final ahead = _fixSpeed > 0.8
          ? _fixSpeed * math.min(sinceFix, _maxPredictSeconds)
          : 0.0;
      arrowProgress = base + ahead;
      final p = _engine.pointAlong(arrowProgress);
      if (p != null) {
        target = p.point;
        _targetHeading = p.bearing;
      }
    }

    // Ease toward it; a big jump (reroute, GPS reacquired) snaps instead.
    if (_distance(_shown, target) > 150) {
      _shown = target;
    } else {
      _shown = LatLng(
        _shown.latitude + (target.latitude - _shown.latitude) * 0.3,
        _shown.longitude + (target.longitude - _shown.longitude) * 0.3,
      );
    }
    final turn = _angleDiff(_shownHeading, _targetHeading);
    _shownHeading = (_shownHeading + turn * 0.2 + 360) % 360;
    final zoomGap = _targetZoom() - _shownZoom;
    _shownZoom += zoomGap * 0.08;

    // Rebuilding the whole screen (and the map widget with its route lines)
    // every tick is what made the arrow stutter on mid/low-end phones. While
    // following, the arrow sits still on screen and only the camera moves;
    // the screen rebuilds only when the captain has panned away and the arrow
    // is a real marker.
    if (_following) {
      _moveCamera();
      _overlayRotation.value = _northUp ? _shownHeading : 0;
      // Erase the line behind the arrow as it moves — a few times a second is
      // enough (the arrow covers the few meters in between) and keeps the
      // map rebuilds cheap.
      if (arrowProgress != null &&
          (arrowProgress - (_trimAt ?? 0)).abs() > 4 &&
          DateTime.now().difference(_trimmedAt).inMilliseconds >= 300) {
        _trimmedAt = DateTime.now();
        setState(() => _trimAt = arrowProgress);
      }
    } else {
      if (arrowProgress != null) _trimAt = arrowProgress;
      setState(() {});
    }

    // Park the timer once everything has settled and nothing is moving.
    final predicting = _fixSpeed > 0.8 && sinceFix < _maxPredictSeconds;
    if (!predicting &&
        _distance(_shown, target) < 0.3 &&
        turn.abs() < 0.5 &&
        zoomGap.abs() < 0.02) {
      _glideTimer?.cancel();
      _glideTimer = null;
    }
  }

  /// Flat-earth distance in meters — plenty for the short gaps compared here.
  double _distance(LatLng a, LatLng b) {
    const mPerDeg = 111320.0;
    final dy = (a.latitude - b.latitude) * mPerDeg;
    final dx = (a.longitude - b.longitude) *
        mPerDeg *
        math.cos(a.latitude * math.pi / 180);
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Signed shortest turn from [from] to [to], in -180..180 degrees.
  double _angleDiff(double from, double to) =>
      ((to - from + 540) % 360) - 180;

  CameraPosition get _followPosition => CameraPosition(
        target: _shown,
        zoom: _shownZoom,
        tilt: _northUp ? 0 : 45, // 3D driving view when heading-up
        bearing: _northUp ? 0 : _shownHeading,
      );

  Future<void> _moveCamera() async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    controller.moveCamera(CameraUpdate.newCameraPosition(_followPosition));
  }

  Future<void> _recenter() async {
    setState(() => _following = true);
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    controller
        .animateCamera(CameraUpdate.newCameraPosition(_followPosition));
  }

  void _toggleNorthUp() {
    setState(() => _northUp = !_northUp);
    _recenter();
  }

  void _showOverview() {
    setState(() => _following = false);
    _frameRoute();
  }

  /// Hand the leg to the Google Maps app (motorcycle mode), falling back to
  /// the web directions page if the app isn't installed.
  Future<void> _openGoogleMaps() async {
    final d = widget.destination;
    final app = Uri.parse(
        'google.navigation:q=${d.latitude},${d.longitude}&mode=l');
    final web = Uri.parse('https://www.google.com/maps/dir/?api=1'
        '&destination=${d.latitude},${d.longitude}&travelmode=driving');
    try {
      if (await launchUrl(app, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    try {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// Closer zoom at low speed and right before a turn, wider when cruising.
  double _targetZoom() {
    final base = _speed < 4
        ? 18.0 // ~<14 km/h
        : _speed < 12
            ? 17.0 // city
            : 16.5; // highway
    final nearTurn = (_update?.distanceToManeuver ?? double.infinity) < 120;
    return nearTurn ? math.max(base, 17.8) : base;
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

  /// Shared by the map marker and the on-screen follow arrow so both look
  /// the same.
  static void _paintArrow(Canvas canvas, double size) {
    // White circular halo so the arrow reads on any map background.
    final halo = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.4, halo);

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
  }

  /// The captain arrow while the camera follows: pinned where the camera
  /// target lands (centre of the padded map area), so moving the camera is
  /// all it takes to "move" the captain.
  Widget _followArrowOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, c) {
            final top = _mapTopPad.h, bottom = _mapBottomPad.h;
            final cy = top + (c.maxHeight - top - bottom) / 2;
            return Stack(
              children: [
                Positioned(
                  left: c.maxWidth / 2 - _followArrowSize / 2,
                  top: cy - _followArrowSize / 2,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _overlayRotation,
                    builder: (_, deg, child) => Transform.rotate(
                      angle: deg * math.pi / 180,
                      child: child,
                    ),
                    child: const CustomPaint(
                      size: Size.square(_followArrowSize),
                      painter: _ArrowPainter(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<BitmapDescriptor> _buildArrowDescriptor() async {
    const size = 96.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _paintArrow(canvas, size);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  Set<Marker> _markers() {
    return {
      // While following, the arrow is the fixed screen overlay instead (see
      // _followArrowOverlay) — no marker moving 20×/s through the plugin.
      if (!_following)
        Marker(
          markerId: const MarkerId('captain'),
          position: _shown,
          icon: _arrowIcon ?? BitmapDescriptor.defaultMarker,
          rotation: _shownHeading,
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
      if (widget.isPickup && _clientLive != null)
        Marker(
          markerId: const MarkerId('client-live'),
          position: _clientLive!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'موقع العميل الحالي'),
        ),
    };
  }

  /// The part of the route still ahead of the arrow. Cached per cut so
  /// rebuilds for other reasons don't re-send an identical polyline.
  List<LatLng> get _routeAhead {
    final key = (_routePoints, _trimAt);
    if (key == _routeAheadKey) return _routeAheadCache;
    _routeAheadKey = key;
    final trim = _trimAt;
    _routeAheadCache = trim == null ? _routePoints : _engine.pathAhead(trim);
    return _routeAheadCache;
  }

  Object? _routeAheadKey;
  List<LatLng> _routeAheadCache = const [];

  /// Only the road still ahead, in brand colour with a dark casing so it
  /// reads on any map background; the driven part is erased behind the arrow.
  Set<Polyline> _polylines() {
    if (_routePoints.isEmpty) return const {};
    final ahead = _routeAhead;
    return {
      Polyline(
        polylineId: const PolylineId('route-casing'),
        points: ahead,
        color: Colors.black.withValues(alpha: 0.55),
        width: 12,
        zIndex: 1,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
      Polyline(
        polylineId: const PolylineId('route'),
        points: ahead,
        color: AppColors.primary,
        width: 8,
        zIndex: 2,
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
    WakelockPlus.disable();
    _gpsWatchdog?.cancel();
    _glideTimer?.cancel();
    _posSub?.cancel();
    _clientSub?.cancel();
    _overlayRotation.dispose();
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
            // Any touch on the map means the captain is looking around: stop
            // following until they tap recenter.
            Listener(
              onPointerDown: (_) {
                if (_following) setState(() => _following = false);
              },
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: widget.origin,
                  zoom: _shownZoom,
                  tilt: 45,
                ),
                // Keeps the arrow below the instruction banner and leaves
                // more road visible ahead of it.
                padding: EdgeInsets.only(
                  top: _mapTopPad.h,
                  bottom: _mapBottomPad.h,
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
            ),
            if (_following) _followArrowOverlay(),

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
                  if (_rerouting)
                    _warningBanner('جارٍ إعادة حساب المسار...'),
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

            // Current speed.
            Positioned(
              left: 16.w,
              bottom: 150.h,
              child: Container(
                width: 64.r,
                height: 64.r,
                decoration: BoxDecoration(
                  color: AppColors.darkGrey,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${(_speed * 3.6).round()}',
                        style: AppStyle.title.copyWith(height: 1)),
                    Text('كم/س', style: AppStyle.body.copyWith(fontSize: 10.sp)),
                  ],
                ),
              ),
            ),

            // Map controls.
            Positioned(
              right: 16.w,
              bottom: 150.h,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _mapButton(
                    icon: Icons.map_outlined,
                    tooltip: 'فتح في خرائط جوجل',
                    onPressed: _openGoogleMaps,
                  ),
                  SizedBox(height: 10.h),
                  _mapButton(
                    icon: Icons.alt_route,
                    tooltip: 'عرض المسار كاملًا',
                    onPressed: _showOverview,
                  ),
                  SizedBox(height: 10.h),
                  _mapButton(
                    icon: _northUp ? Icons.explore : Icons.navigation,
                    tooltip: _northUp ? 'الشمال لأعلى' : 'باتجاه الحركة',
                    onPressed: _toggleNorthUp,
                  ),
                  SizedBox(height: 10.h),
                  if (_following)
                    _mapButton(
                      icon: Icons.my_location,
                      tooltip: 'إعادة التمركز',
                      onPressed: _recenter,
                    )
                  else
                    FloatingActionButton.extended(
                      heroTag: null,
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.black,
                      onPressed: _recenter,
                      icon: const Icon(Icons.navigation),
                      label: Text('إعادة التمركز',
                          style: AppStyle.button
                              .copyWith(color: AppColors.black)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return FloatingActionButton.small(
      heroTag: null,
      tooltip: tooltip,
      backgroundColor: AppColors.darkGrey,
      foregroundColor: AppColors.primary,
      onPressed: onPressed,
      child: Icon(icon),
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

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter();

  @override
  void paint(Canvas canvas, Size size) =>
      _NavigationScreenState._paintArrow(canvas, size.shortestSide);

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => false;
}
