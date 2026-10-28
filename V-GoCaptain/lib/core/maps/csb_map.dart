// V-Go's map facade, ported from CSB: Google-shaped types over MapLibre.
// GeoJSON layers replace overlay sets in one update; pins are painted locally
// and PNG images registered once per style. Tiles come from OpenFreeMap.
// MapLibre uses 512 px tiles versus Google's 256: subtract one zoom level on
// the way in, add one on the way out to preserve the screens' camera scales.
// LatLng is MapLibre's type: longitude modulo can introduce ~1e-14 drift;
// coordinate assertions should use a tolerance.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:maplibre_gl/maplibre_gl.dart'
    show LatLng, LatLngBounds, CameraPosition;

export 'package:maplibre_gl/maplibre_gl.dart'
    show LatLng, LatLngBounds, CameraPosition;

const double _zoomShift = 1;

double toMapLibreZoom(double zoom) => zoom - _zoomShift;
double fromMapLibreZoom(double zoom) => zoom + _zoomShift;

/// Shift only zoom; navigation's target, heading and pitch stay intact.
CameraPosition toMapLibreCameraPosition(CameraPosition position) =>
    CameraPosition(
      target: position.target,
      zoom: toMapLibreZoom(position.zoom),
      bearing: position.bearing,
      tilt: position.tilt,
    );

CameraPosition fromMapLibreCameraPosition(CameraPosition position) =>
    CameraPosition(
      target: position.target,
      zoom: fromMapLibreZoom(position.zoom),
      bearing: position.bearing,
      tilt: position.tilt,
    );

// ─────────────────────────── ids ───────────────────────────

class MarkerId {
  const MarkerId(this.value);
  final String value;
  @override
  bool operator ==(Object other) => other is MarkerId && other.value == value;
  @override
  int get hashCode => value.hashCode;
}

class PolylineId {
  const PolylineId(this.value);
  final String value;
  @override
  bool operator ==(Object other) => other is PolylineId && other.value == value;
  @override
  int get hashCode => value.hashCode;
}

class CircleId {
  const CircleId(this.value);
  final String value;
  @override
  bool operator ==(Object other) => other is CircleId && other.value == value;
  @override
  int get hashCode => value.hashCode;
}

// ─────────────────────────── icons ───────────────────────────

/// A marker image: either a classic pin in a hue, or PNG bytes drawn at a
/// logical width. Registered with the map once per distinct image and then
/// referenced by name from every marker that uses it.
class BitmapDescriptor {
  const BitmapDescriptor._({this.hue, this.png, this.width});

  final double? hue;
  final Uint8List? png;
  final double? width;

  static const double hueRed = 0;
  static const double hueOrange = 30;
  static const double hueYellow = 60;
  static const double hueGreen = 120;
  static const double hueCyan = 180;
  static const double hueAzure = 210;
  static const double hueBlue = 240;
  static const double hueViolet = 270;
  static const double hueMagenta = 300;
  static const double hueRose = 330;

  static const BitmapDescriptor defaultMarker = BitmapDescriptor._(hue: hueRed);

  static BitmapDescriptor defaultMarkerWithHue(double hue) => BitmapDescriptor._(hue: hue % 360);

  /// PNG [bytes] shown [width] logical pixels wide (the image's own width when
  /// null).
  static BitmapDescriptor bytes(Uint8List bytes, {double? width, double? height}) =>
      BitmapDescriptor._(png: bytes, width: width ?? height);

  /// Anchor a pin at its tip, an image at its centre — Google's defaults.
  bool get isPin => hue != null;

  String get imageKey => isPin ? 'vgo_pin_${hue!.round()}' : 'vgo_img_${_fnv(png!)}';

  static int _fnv(Uint8List b) {
    var h = 0x811c9dc5;
    final step = math.max(1, b.length ~/ 4096);
    for (var i = 0; i < b.length; i += step) {
      h = ((h ^ b[i]) * 0x01000193) & 0xffffffff;
    }
    return (h ^ b.length) & 0xffffffff;
  }
}

class InfoWindow {
  const InfoWindow({this.title, this.snippet});
  final String? title;
  final String? snippet;
  static const InfoWindow noText = InfoWindow();
}

// ─────────────────────────── overlays ───────────────────────────

class Marker {
  const Marker({
    required this.markerId,
    required this.position,
    this.icon = BitmapDescriptor.defaultMarker,
    this.anchor = const Offset(0.5, 1.0),
    this.onTap,
    this.infoWindow = InfoWindow.noText,
    this.zIndex = 0,
    this.zIndexInt,
    this.rotation = 0,
    this.flat = false,
    this.alpha = 1,
    this.visible = true,
    this.consumeTapEvents = false,
  });

  final MarkerId markerId;
  final LatLng position;
  final BitmapDescriptor icon;
  final Offset anchor;
  final VoidCallback? onTap;
  final InfoWindow infoWindow;
  final double zIndex;
  final int? zIndexInt;
  double get sortKey => (zIndexInt ?? zIndex).toDouble();
  final double rotation;
  final bool flat;
  final double alpha;
  final bool visible;
  final bool consumeTapEvents;
}

class PatternItem {
  const PatternItem._(this.isDash, this.length);
  final bool isDash;
  final double length;
  static PatternItem dash(double length) => PatternItem._(true, length);
  static PatternItem gap(double length) => PatternItem._(false, length);
  static const PatternItem dot = PatternItem._(true, 1);
}

class Cap {
  const Cap._(this.value);
  final String value;
  static const Cap buttCap = Cap._('butt');
  static const Cap roundCap = Cap._('round');
  static const Cap squareCap = Cap._('square');
}

class JointType {
  const JointType._(this.value);
  final String value;
  static const JointType mitered = JointType._('miter');
  static const JointType bevel = JointType._('bevel');
  static const JointType round = JointType._('round');
}

class Polyline {
  const Polyline({
    required this.polylineId,
    this.points = const [],
    this.color = Colors.black,
    this.width = 10,
    this.patterns = const [],
    this.startCap = Cap.buttCap,
    this.endCap = Cap.buttCap,
    this.jointType = JointType.mitered,
    this.zIndex = 0,
    this.visible = true,
    this.geodesic = false,
    this.onTap,
    this.consumeTapEvents = false,
  });

  final PolylineId polylineId;
  final List<LatLng> points;
  final Color color;
  final int width;
  final List<PatternItem> patterns;
  final Cap startCap;
  final Cap endCap;
  final JointType jointType;
  final double zIndex;
  final bool visible;
  final bool geodesic;
  final VoidCallback? onTap;
  final bool consumeTapEvents;

  bool get dashed => patterns.any((p) => !p.isDash);
}

class Circle {
  const Circle({
    required this.circleId,
    required this.center,
    this.radius = 0,
    this.fillColor = Colors.transparent,
    this.strokeColor = Colors.black,
    this.strokeWidth = 10,
    this.zIndex = 0,
    this.visible = true,
  });

  final CircleId circleId;
  final LatLng center;

  /// Metres.
  final double radius;
  final Color fillColor;
  final Color strokeColor;
  final int strokeWidth;
  final double zIndex;
  final bool visible;
}

// ─────────────────────────── camera ───────────────────────────

class CameraUpdate {
  const CameraUpdate._(this._build);
  final ml.CameraUpdate Function() _build;

  static CameraUpdate newLatLng(LatLng latLng) => CameraUpdate._(() => ml.CameraUpdate.newLatLng(latLng));

  static CameraUpdate newLatLngZoom(LatLng latLng, double zoom) =>
      CameraUpdate._(() => ml.CameraUpdate.newLatLngZoom(latLng, toMapLibreZoom(zoom)));

  static CameraUpdate newLatLngBounds(LatLngBounds bounds, double padding) => CameraUpdate._(
        () => ml.CameraUpdate.newLatLngBounds(
          bounds,
          left: padding,
          top: padding,
          right: padding,
          bottom: padding,
        ),
      );

  static CameraUpdate newCameraPosition(CameraPosition p) => CameraUpdate._(
        () => ml.CameraUpdate.newCameraPosition(
          toMapLibreCameraPosition(p),
        ),
      );

  static CameraUpdate zoomTo(double zoom) => CameraUpdate._(() => ml.CameraUpdate.zoomTo(toMapLibreZoom(zoom)));
  static CameraUpdate zoomIn() => CameraUpdate._(ml.CameraUpdate.zoomIn);
  static CameraUpdate zoomOut() => CameraUpdate._(ml.CameraUpdate.zoomOut);
}

class MinMaxZoomPreference {
  const MinMaxZoomPreference(this.minZoom, this.maxZoom);
  final double? minZoom;
  final double? maxZoom;
  static const MinMaxZoomPreference unbounded = MinMaxZoomPreference(null, null);
}

class VgoMapController {
  VgoMapController._(this._ml);
  final ml.MapLibreMapController _ml;

  Future<void> animateCamera(CameraUpdate update) async {
    if (_ml.isDisposed) return;
    await _ml.animateCamera(update._build());
  }

  Future<void> moveCamera(CameraUpdate update) async {
    if (_ml.isDisposed) return;
    await _ml.moveCamera(update._build());
  }

  Future<LatLngBounds> getVisibleRegion() => _ml.getVisibleRegion();

  Future<double> getZoomLevel() async => fromMapLibreZoom(_ml.cameraPosition?.zoom ?? 0);

  /// Screens dispose their controller in State.dispose; the map widget owns
  /// the native view, so there is nothing to do here.
  void dispose() {}
}

// ─────────────────────────── the widget ───────────────────────────

class VgoMap extends StatefulWidget {
  const VgoMap({
    super.key,
    required this.initialCameraPosition,
    this.myLocationEnabled = false,
    this.myLocationButtonEnabled = true,
    this.zoomControlsEnabled = true,
    this.compassEnabled = true,
    this.mapToolbarEnabled = true,
    this.rotateGesturesEnabled = true,
    this.tiltGesturesEnabled = true,
    this.scrollGesturesEnabled = true,
    this.zoomGesturesEnabled = true,
    this.gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{},
    this.minMaxZoomPreference = MinMaxZoomPreference.unbounded,
    // Google-only layers; accepted so a screen can keep its flags, drawn by
    // nothing. There is no live traffic layer without Google.
    this.buildingsEnabled = false,
    this.trafficEnabled = false,
    this.markers = const <Marker>{},
    this.polylines = const <Polyline>{},
    this.circles = const <Circle>{},
    this.padding = EdgeInsets.zero,
    this.onMapCreated,
    this.onTap,
    this.onLongPress,
    this.onCameraMoveStarted,
    this.onCameraMove,
    this.onCameraIdle,
  });

  final CameraPosition initialCameraPosition;

  final bool myLocationEnabled;
  // Compatibility flags only; Captain supplies its own controls.
  final bool myLocationButtonEnabled;
  final bool zoomControlsEnabled;
  final bool compassEnabled;
  // Google's launch-maps toolbar has no MapLibre equivalent.
  final bool mapToolbarEnabled;
  final bool rotateGesturesEnabled;
  final bool tiltGesturesEnabled;
  final bool scrollGesturesEnabled;
  final bool zoomGesturesEnabled;
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;
  final MinMaxZoomPreference minMaxZoomPreference;
  final bool buildingsEnabled;
  final bool trafficEnabled;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final Set<Circle> circles;
  final EdgeInsets padding;
  final void Function(VgoMapController controller)? onMapCreated;
  final void Function(LatLng point)? onTap;
  final void Function(LatLng point)? onLongPress;
  final VoidCallback? onCameraMoveStarted;
  final void Function(CameraPosition position)? onCameraMove;
  final VoidCallback? onCameraIdle;

  @override
  State<VgoMap> createState() => _VgoMapState();
}

const String _srcMarkers = 'vgo-markers';
const String _srcLines = 'vgo-lines';
const String _srcLinesDashed = 'vgo-lines-dashed';
const String _srcFills = 'vgo-fills';
const String _layerMarkers = 'vgo-markers';
const String _layerMarkersFlat = 'vgo-markers-flat';

class _VgoMapState extends State<VgoMap> {
  ml.MapLibreMapController? _ml;
  VgoMapController? _controller;
  bool _styleReady = false;
  bool _wasMoving = false;
  final Set<String> _images = {};
  final Map<String, Marker> _byId = {};
  bool _syncing = false;
  bool _syncAgain = false;
  String? _tooltip;
  Timer? _tooltipTimer;
  // Bumped on every style load, so a retry left over from the previous style
  // stands down.
  int _styleGen = 0;

  double get _dpr => MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2;

  @override
  void didUpdateWidget(covariant VgoMap old) {
    super.didUpdateWidget(old);
    if (old.padding != widget.padding) unawaited(_applyPadding());
    if (!identical(old.markers, widget.markers) ||
        !identical(old.polylines, widget.polylines) ||
        !identical(old.circles, widget.circles)) {
      _scheduleSync();
    }
  }

  @override
  void dispose() {
    _styleGen++;
    _tooltipTimer?.cancel();
    _ml?.removeListener(_onCameraChanged);
    _ml?.onFeatureTapped.remove(_onFeatureTapped);
    super.dispose();
  }

  Future<void> _onMapCreated(ml.MapLibreMapController c) async {
    _ml = c;
    _controller = VgoMapController._(c);
    c.addListener(_onCameraChanged);
    c.onFeatureTapped.add(_onFeatureTapped);
    // The fixed navigation arrow sits at the centre of the padded viewport.
    await _applyPadding();
    if (!mounted || c.isDisposed) return;
    widget.onMapCreated?.call(_controller!);
  }

  Future<void> _applyPadding() async {
    final c = _ml;
    if (!mounted || c == null || c.isDisposed) return;
    try {
      await c.updateContentInsets(widget.padding);
    } catch (e) {
      debugPrint('vgo_map: viewport padding failed: $e');
    }
  }

  void _onCameraChanged() {
    final c = _ml;
    if (c == null) return;
    if (c.isCameraMoving && !_wasMoving) widget.onCameraMoveStarted?.call();
    _wasMoving = c.isCameraMoving;
  }

  void _onCameraMove(CameraPosition p) {
    widget.onCameraMove?.call(
      fromMapLibreCameraPosition(p),
    );
  }

  Future<void> _onStyleLoaded() async {
    final gen = ++_styleGen;
    // Native style reloads drop every image and source, even with one style.
    _images.clear();
    _iconSizes.clear();
    _styleReady = false;
    // First launch / activity recreation can announce a style before layers
    // are accepted. Retry briefly so pins and routes don't stay missing.
    for (final wait in const [0, 250, 700, 1500, 3000]) {
      if (wait > 0) await Future<void>.delayed(Duration(milliseconds: wait));
      final c = _ml;
      if (!mounted || c == null || c.isDisposed || gen != _styleGen) return;
      try {
        await _addOverlayLayers(c);
        if (!mounted || c.isDisposed || gen != _styleGen) return;
        _styleReady = true;
        _scheduleSync();
        return;
      } catch (e) {
        if (!mounted || c.isDisposed || gen != _styleGen) return;
        debugPrint('vgo_map: style setup failed (will retry): $e');
        // Whatever half of it landed would make the next attempt fail on
        // "already exists".
        await _removeOverlayLayers(c);
      }
    }
  }

  static const _overlayLayers = [
    'vgo-fills',
    'vgo-fills-stroke',
    'vgo-lines',
    'vgo-lines-dashed',
    _layerMarkersFlat,
    _layerMarkers,
  ];
  static const _overlaySources = [_srcFills, _srcLines, _srcLinesDashed, _srcMarkers];

  Future<void> _removeOverlayLayers(ml.MapLibreMapController c) async {
    for (final id in _overlayLayers) {
      try {
        await c.removeLayer(id);
      } catch (_) {}
    }
    for (final id in _overlaySources) {
      try {
        await c.removeSource(id);
      } catch (_) {}
    }
  }

  Future<void> _addOverlayLayers(ml.MapLibreMapController c) async {
    const empty = {'type': 'FeatureCollection', 'features': []};
    await c.addGeoJsonSource(_srcFills, empty);
    await c.addFillLayer(
      _srcFills,
      'vgo-fills',
      const ml.FillLayerProperties(
        fillColor: ['get', 'fill'],
        fillOpacity: ['get', 'fillOpacity'],
      ),
      enableInteraction: false,
    );
    await c.addLineLayer(
      _srcFills,
      'vgo-fills-stroke',
      const ml.LineLayerProperties(
        lineColor: ['get', 'stroke'],
        lineOpacity: ['get', 'strokeOpacity'],
        lineWidth: ['get', 'strokeWidth'],
      ),
      enableInteraction: false,
    );
    await c.addGeoJsonSource(_srcLines, empty);
    await c.addLineLayer(
      _srcLines,
      'vgo-lines',
      const ml.LineLayerProperties(
        lineColor: ['get', 'color'],
        lineOpacity: ['get', 'opacity'],
        lineWidth: ['get', 'width'],
        lineCap: 'round',
        lineJoin: 'round',
      ),
      enableInteraction: false,
    );
    await c.addGeoJsonSource(_srcLinesDashed, empty);
    await c.addLineLayer(
      _srcLinesDashed,
      'vgo-lines-dashed',
      const ml.LineLayerProperties(
        lineColor: ['get', 'color'],
        lineOpacity: ['get', 'opacity'],
        lineWidth: ['get', 'width'],
        lineDasharray: [1.5, 2],
        lineCap: 'butt',
        lineJoin: 'round',
      ),
      enableInteraction: false,
    );
    await c.addGeoJsonSource(_srcMarkers, empty);
    // Two symbol layers because rotation alignment is a layout property,
    // not a data-driven one: a flat captain marker turns with the
    // map, every other one stays upright.
    for (final flat in [true, false]) {
      await c.addSymbolLayer(
        _srcMarkers,
        flat ? _layerMarkersFlat : _layerMarkers,
        ml.SymbolLayerProperties(
          iconImage: const ['get', 'icon'],
          iconSize: const ['get', 'size'],
          iconAnchor: const ['get', 'anchor'],
          iconRotate: const ['get', 'rotate'],
          iconOpacity: const ['get', 'alpha'],
          symbolSortKey: const ['get', 'z'],
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconRotationAlignment: flat ? 'map' : 'viewport',
        ),
        filter: ['==', ['get', 'flat'], flat],
      );
    }
  }

  void _scheduleSync() {
    if (!mounted || !_styleReady) return;
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    _sync().then((ok) {
      _syncing = false;
      if (_syncAgain) {
        _syncAgain = false;
        _scheduleSync();
      } else if (!ok && _syncRetries < 4) {
        // Unchanged pickup pins may never trigger another build after failure.
        _syncRetries++;
        Future<void>.delayed(Duration(milliseconds: 400 * _syncRetries), () {
          if (mounted) _scheduleSync();
        });
      } else if (ok) {
        _syncRetries = 0;
      }
    });
  }

  int _syncRetries = 0;

  Future<bool> _sync() async {
    final c = _ml;
    if (c == null || c.isDisposed || !mounted) return true;
    try {
      await _syncMarkers(c);
      await c.setGeoJsonSource(_srcLines, _linesJson(dashed: false));
      await c.setGeoJsonSource(_srcLinesDashed, _linesJson(dashed: true));
      await c.setGeoJsonSource(_srcFills, _fillsJson());
      return true;
    } catch (e) {
      debugPrint('vgo_map: sync failed: $e');
      return false;
    }
  }

  Future<void> _syncMarkers(ml.MapLibreMapController c) async {
    final dpr = _dpr;
    final features = <Map<String, dynamic>>[];
    _byId.clear();
    for (final m in widget.markers) {
      if (!m.visible) continue;
      _byId[m.markerId.value] = m;
      final key = m.icon.imageKey;
      var size = 1.0;
      if (!_images.contains(key)) {
        final rendered = await _renderIcon(m.icon, dpr);
        if (rendered == null) continue;
        await c.addImage(key, rendered.bytes);
        _images.add(key);
        _iconSizes[key] = rendered.size;
      }
      size = _iconSizes[key] ?? 1.0;
      features.add({
        'type': 'Feature',
        'id': m.markerId.value,
        'geometry': {
          'type': 'Point',
          'coordinates': [m.position.longitude, m.position.latitude],
        },
        'properties': {
          'mid': m.markerId.value,
          'icon': key,
          'size': size,
          'anchor': _anchorName(m.anchor),
          'rotate': m.rotation,
          'alpha': m.alpha,
          'z': m.sortKey,
          'flat': m.flat,
        },
      });
    }
    await c.setGeoJsonSource(_srcMarkers, {'type': 'FeatureCollection', 'features': features});
  }

  final Map<String, double> _iconSizes = {};

  static String _anchorName(Offset a) {
    final h = a.dx < 0.25 ? 'left' : (a.dx > 0.75 ? 'right' : '');
    final v = a.dy < 0.25 ? 'top' : (a.dy > 0.75 ? 'bottom' : '');
    if (h.isEmpty && v.isEmpty) return 'center';
    if (h.isEmpty) return v;
    if (v.isEmpty) return h;
    return '$v-$h';
  }

  Map<String, dynamic> _linesJson({required bool dashed}) {
    final features = <Map<String, dynamic>>[];
    for (final p in widget.polylines) {
      if (!p.visible || p.dashed != dashed || p.points.length < 2) continue;
      features.add({
        'type': 'Feature',
        'id': p.polylineId.value,
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            for (final pt in p.points) [pt.longitude, pt.latitude],
          ],
        },
        'properties': {
          'color': _hex(p.color),
          'opacity': p.color.a,
          // Google widths are pixels; MapLibre's are too, but a Google line
          // reads a shade heavier for the same number.
          'width': p.width * 0.75,
          'z': p.zIndex,
        },
      });
    }
    // Draw order inside one layer follows feature order.
    features.sort((a, b) => (a['properties']['z'] as double).compareTo(b['properties']['z'] as double));
    return {'type': 'FeatureCollection', 'features': features};
  }

  Map<String, dynamic> _fillsJson() {
    final features = <Map<String, dynamic>>[];
    for (final ci in widget.circles) {
      if (!ci.visible || ci.radius <= 0) continue;
      features.add({
        'type': 'Feature',
        'id': ci.circleId.value,
        'geometry': {
          'type': 'Polygon',
          'coordinates': [_circleRing(ci.center, ci.radius)],
        },
        'properties': {
          'fill': _hex(ci.fillColor),
          'fillOpacity': ci.fillColor.a,
          'stroke': _hex(ci.strokeColor),
          'strokeOpacity': ci.strokeColor.a,
          'strokeWidth': ci.strokeWidth * 0.75,
        },
      });
    }
    return {'type': 'FeatureCollection', 'features': features};
  }

  static List<List<double>> _circleRing(LatLng c, double radiusM) {
    const n = 48;
    final latR = c.latitude * math.pi / 180;
    final dLat = radiusM / 111320.0;
    final dLng = radiusM / (111320.0 * math.cos(latR));
    final ring = <List<double>>[];
    for (var i = 0; i <= n; i++) {
      final t = 2 * math.pi * i / n;
      ring.add([c.longitude + dLng * math.cos(t), c.latitude + dLat * math.sin(t)]);
    }
    return ring;
  }

  static String _hex(Color c) {
    String two(double v) => (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${two(c.r)}${two(c.g)}${two(c.b)}';
  }

  void _onFeatureTapped(math.Point<double> point, LatLng latLng, String id, String layerId, ml.Annotation? _) {
    if (layerId != _layerMarkers && layerId != _layerMarkersFlat) return;
    final m = _byId[id];
    if (m == null) return;
    if (m.onTap != null) {
      m.onTap!();
      return;
    }
    final title = m.infoWindow.title;
    if (title != null && title.isNotEmpty) _showTooltip(title);
  }

  void _showTooltip(String text) {
    _tooltipTimer?.cancel();
    setState(() => _tooltip = text);
    _tooltipTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _tooltip = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final init = widget.initialCameraPosition;
    return Stack(
      fit: StackFit.expand,
      children: [
        ml.MapLibreMap(
          styleString: vgoMapStyle,
          initialCameraPosition: toMapLibreCameraPosition(init),
          myLocationEnabled: widget.myLocationEnabled,
          myLocationRenderMode: ml.MyLocationRenderMode.normal,
          myLocationTrackingMode: ml.MyLocationTrackingMode.none,
          compassEnabled: widget.compassEnabled,
          rotateGesturesEnabled: widget.rotateGesturesEnabled,
          tiltGesturesEnabled: widget.tiltGesturesEnabled,
          scrollGesturesEnabled: widget.scrollGesturesEnabled,
          zoomGesturesEnabled: widget.zoomGesturesEnabled,
          gestureRecognizers: widget.gestureRecognizers,
          minMaxZoomPreference: ml.MinMaxZoomPreference(
            widget.minMaxZoomPreference.minZoom == null ? null : toMapLibreZoom(widget.minMaxZoomPreference.minZoom!),
            widget.minMaxZoomPreference.maxZoom == null ? null : toMapLibreZoom(widget.minMaxZoomPreference.maxZoom!),
          ),
          trackCameraPosition: true,
          featureTapsTriggersMapClick: false,
          // OpenStreetMap's licence asks for its credit; the small button keeps
          // it out of the way of the pins.
          attributionButtonPosition: ml.AttributionButtonPosition.bottomLeft,
          attributionButtonMargins: math.Point(8 + widget.padding.left, 8 + widget.padding.bottom),
          logoViewMargins: math.Point(8 + widget.padding.left, 8 + widget.padding.bottom),
          // We use GeoJSON layers. Disable unused annotation managers so an
          // early native-layer failure cannot swallow our style-ready callback.
          annotationOrder: const [],
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
          onMapClick: widget.onTap == null ? null : (_, p) => widget.onTap!(p),
          onMapLongClick: widget.onLongPress == null ? null : (_, p) => widget.onLongPress!(p),
          onCameraMove: widget.onCameraMove == null ? null : _onCameraMove,
          onCameraIdle: widget.onCameraIdle,
        ),
        if (_tooltip != null)
          Positioned(
            top: 12 + widget.padding.top,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Material(
                  color: const Color(0xEE141414),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Text(
                      _tooltip!,
                      style: const TextStyle(color: Color(0xFFF5F0E1), fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────── icon rendering ───────────────────────────

class _RenderedIcon {
  const _RenderedIcon(this.bytes, this.size);
  final Uint8List bytes;

  /// The `icon-size` factor that draws the image at its intended logical width.
  final double size;
}

/// Images are handed to the native side as raw PNG bytes and drawn at the
/// screen's pixel ratio, so a PNG painted at `width × dpr` pixels lands
/// `width` logical pixels wide at size 1. Anything else is scaled from that.
Future<_RenderedIcon?> _renderIcon(BitmapDescriptor icon, double dpr) async {
  if (icon.isPin) return _RenderedIcon(await _paintPin(icon.hue!, dpr), 1);
  final bytes = icon.png!;
  final width = icon.width;
  if (width == null) return _RenderedIcon(bytes, 1 / dpr);
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final px = frame.image.width.toDouble();
    frame.image.dispose();
    codec.dispose();
    return _RenderedIcon(bytes, (width * dpr) / px);
  } catch (_) {
    return null;
  }
}

const double _pinW = 26;
const double _pinH = 38;

Future<Uint8List> _paintPin(double hue, double dpr) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.scale(dpr);
  final color = HSVColor.fromAHSV(1, hue, 0.82, 0.96).toColor();
  final dark = HSVColor.fromAHSV(1, hue, 0.9, 0.7).toColor();
  const cx = _pinW / 2;
  const r = _pinW / 2 - 1;
  final path = Path()
    ..moveTo(cx, _pinH - 1)
    ..quadraticBezierTo(cx - r * 0.9, _pinH - 14, cx - r, r + 1)
    ..arcToPoint(Offset(cx + r, r + 1), radius: const Radius.circular(r), largeArc: true)
    ..quadraticBezierTo(cx + r * 0.9, _pinH - 14, cx, _pinH - 1)
    ..close();
  canvas.drawShadow(path, Colors.black, 3, true);
  canvas.drawPath(path, Paint()..color = color);
  canvas.drawPath(
    path,
    Paint()
      ..color = dark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2,
  );
  canvas.drawCircle(const Offset(cx, r + 1), r * 0.38, Paint()..color = const Color(0xFFFFFFFF));
  final img = await rec.endRecording().toImage((_pinW * dpr).ceil(), (_pinH * dpr).ceil());
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return png!.buffer.asUint8List();
}

// ─────────────────────────── styles ───────────────────────────

// Bundled Arabic-first light style; tiles, fonts and sprites use OpenFreeMap.
const String vgoMapStyle = 'assets/map/vgo-light.json';
