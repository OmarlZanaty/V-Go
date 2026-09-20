import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Arabic voice guidance. Wraps flutter_tts with Egyptian Arabic settings and
/// de-duplication so the same phrase isn't spoken twice in a row.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  String? _lastSpoken;

  Future<void> init() async {
    if (_ready) return;
    try {
      await _tts.setLanguage('ar-EG');
      await _tts.setSpeechRate(0.5); // calmer pace for driving
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      // Queue instructions instead of cutting each other off mid-word.
      await _tts.awaitSpeakCompletion(true);
      _ready = true;
    } catch (e) {
      debugPrint('TTS init failed: $e');
    }
  }

  /// Speak [text]. If [dedupe] is true (default) the same text won't be repeated
  /// back-to-back — the engine calls this on every GPS tick within a threshold.
  Future<void> speak(String text, {bool dedupe = true}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (!_ready) await init();
    if (dedupe && trimmed == _lastSpoken) return;
    _lastSpoken = trimmed;
    try {
      await _tts.stop();
      await _tts.speak(trimmed);
    } catch (e) {
      debugPrint('TTS speak failed: $e');
    }
  }

  /// Clears the de-dupe memory so the next instruction is always spoken (used
  /// when advancing to a new step).
  void resetDedupe() => _lastSpoken = null;

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
  }
}
