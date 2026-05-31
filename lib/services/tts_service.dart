import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> init({String lang = 'en-US', double rate = 0.45}) async {
    if (_initialized) return;
    try {
      await _tts.setLanguage(lang);
      await _tts.setSpeechRate(rate);
      _initialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('Tts init error: $e');
    }
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    try {
      await _tts.speak(text);
    } catch (e) {
      if (kDebugMode) debugPrint('Tts speak error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
  }
}
