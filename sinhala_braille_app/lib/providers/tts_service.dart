import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Singleton TTS + STT service.
///
/// - [speakSinhala] → uses si-LK locale (document content)
/// - [speakEnglish] → uses en-US locale (UI labels, instructions)
/// - [startListening] / [stopListening] → STT voice dictation
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();

  bool _sttAvailable = false;
  bool _speaking = false;

  bool get isSpeaking => _speaking;

  // ── Initialisation ──────────────────────────────────────────────────────

  Future<void> init() async {
    // Common TTS settings
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);

    _tts.setStartHandler(() => _speaking = true);
    _tts.setCompletionHandler(() => _speaking = false);
    _tts.setCancelHandler(() => _speaking = false);
    _tts.setErrorHandler((_) => _speaking = false);

    // Try to initialize STT (may fail on emulators)
    try {
      _sttAvailable = await _stt.initialize(
        onError: (e) => debugPrint('STT error: $e'),
        onStatus: (s) => debugPrint('STT status: $s'),
      );
    } catch (e) {
      debugPrint('STT init failed: $e');
      _sttAvailable = false;
    }
  }

  // ── Speak Sinhala (si-LK) ───────────────────────────────────────────────

  Future<void> speakSinhala(String text) async {
    await _tts.stop();
    await _tts.setLanguage('si-LK');
    // Fallback: if Sinhala not supported, use English
    final List<dynamic> langs = await _tts.getLanguages;
    if (!langs.contains('si-LK') && !langs.contains('si')) {
      await _tts.setLanguage('en-US');
    }
    await _tts.speak(text);
  }

  // ── Speak English (en-US) ───────────────────────────────────────────────

  Future<void> speakEnglish(String text) async {
    await _tts.stop();
    await _tts.setLanguage('en-US');
    await _tts.speak(text);
  }

  // ── Playback controls ───────────────────────────────────────────────────

  Future<void> pause() async {
    await _tts.pause();
    _speaking = false;
  }

  Future<void> stop() async {
    await _tts.stop();
    _speaking = false;
  }

  // ── Speech-to-Text (voice dictation) ───────────────────────────────────

  bool get sttAvailable => _sttAvailable;

  /// Starts listening. [onResult] receives the transcribed text.
  /// [locale] defaults to 'en_US' for field dictation.
  Future<void> startListening({
    required void Function(String result, bool isFinal) onResult,
    String locale = 'en_US',
  }) async {
    if (!_sttAvailable) return;

    // Stop any ongoing TTS before listening
    await stop();

    await _stt.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: locale,
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
      ),
    );
  }

  Future<void> stopListening() async {
    await _stt.stop();
  }

  bool get isListening => _stt.isListening;
}
