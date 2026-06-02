// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<void> setMapStyle(
  BuildContext context,
  GoogleMapController controller,
) async {
  final String style = await DefaultAssetBundle.of(
    context,
  ).loadString('assets/map_style.json');
  await controller.setMapStyle(style);
}
