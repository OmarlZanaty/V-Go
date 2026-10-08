import 'dart:io';

import 'package:firebase_core/firebase_core.dart';

/// Firebase for the captain app. Android reads android/app/google-services.json;
/// iOS uses the "V-Go Captain iOS" app registered in the same v-go-46d8c project,
/// so no GoogleService-Info.plist has to be added to the Xcode project.
class CaptainFirebaseOptions {
  CaptainFirebaseOptions._();

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAIAdUP1WhwQm7vBaFH7qIaWLG5JOkev_Q',
    appId: '1:1009005156907:ios:1e2f888c20a5508f0c686e',
    messagingSenderId: '1009005156907',
    projectId: 'v-go-46d8c',
    storageBucket: 'v-go-46d8c.firebasestorage.app',
    iosBundleId: 'com.scooterapp.vgo.vGoCaptain',
  );

  /// Options to pass to [Firebase.initializeApp] (null = native config).
  static FirebaseOptions? get currentPlatform => Platform.isIOS ? ios : null;
}
