import 'package:flutter_test/flutter_test.dart';
import 'package:scooter_app/core/maps/csb_map.dart';

void main() {
  test('camera conversion shifts zoom without changing navigation pose', () {
    const camera = CameraPosition(
      target: LatLng(30.0444, 391.2357),
      zoom: 17.5,
      bearing: 125,
      tilt: 45,
    );

    final native = toMapLibreCameraPosition(camera);
    expect(native.zoom, 16.5);
    expect(native.target.latitude, closeTo(30.0444, 1e-10));
    // MapLibre normalises longitudes with modulo, allowing tiny float drift.
    expect(native.target.longitude, closeTo(31.2357, 1e-10));
    expect(native.bearing, 125);
    expect(native.tilt, 45);

    final restored = fromMapLibreCameraPosition(native);
    expect(restored.zoom, camera.zoom);
    expect(restored.target, camera.target);
    expect(restored.bearing, camera.bearing);
    expect(restored.tilt, camera.tilt);
    expect(toMapLibreZoom(12), 11);
    expect(fromMapLibreZoom(11), 12);
  });
}
