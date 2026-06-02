import 'dart:io';

import 'package:dio/dio.dart';

Future uploadImageToApi(File image) async {
  return MultipartFile.fromFile(
    image.path,
    filename: image.path.split('/').last,
  );
}
