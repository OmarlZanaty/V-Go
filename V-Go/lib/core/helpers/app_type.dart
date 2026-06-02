import 'dart:developer';

import 'package:flutter/foundation.dart';

String deviceType() {
  log('defaultTargetPlatform: $defaultTargetPlatform');
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return 'Ios';
  } else {
    return 'Android';
  }
}
