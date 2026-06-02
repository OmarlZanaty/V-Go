import 'dart:developer';

import 'package:audioplayers/audioplayers.dart';

Future<void> playNotificationSound(SoundType type) async {
  final AudioPlayer audioPlayer = AudioPlayer();
  bool canPlaySound = true;

  if (canPlaySound) {
    canPlaySound = false;
    try {
      await audioPlayer.play(AssetSource('sounds/${type.name}.wav'));
      await Future.delayed(const Duration(milliseconds: 1200));
      canPlaySound = true;
    } catch (e) {
      log('Error playing sound: $e');
      canPlaySound = true;
    } finally {
      await audioPlayer.dispose();
    }
  }
}

enum SoundType { accept, cancel, free,bell,begin }
