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
  bool _isEngineReady = false;
  bool _isSinhalaSupported = false;

  /// All voices available on the current device, cached at init time.
  List<Map<String, String>> _voices = [];

  bool get isSpeaking => _speaking;
  bool get isEngineReady => _isEngineReady;
  bool get isSinhalaSupported => _isSinhalaSupported;

  /// Optional callback for character/word progress tracking (FR 25).
  void Function(String text, int start, int end, String word)? onProgress;

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
    _tts.setProgressHandler((String text, int start, int end, String word) {
      onProgress?.call(text, start, end, word);
    });

    // Check Sinhala language pack support (FR 24)
    try {
      final List<dynamic> langs = await _tts.getLanguages;
      _isSinhalaSupported = langs.contains('si-LK') || langs.contains('si');
    } catch (e) {
      debugPrint('Error checking languages: $e');
      _isSinhalaSupported = false;
    }

    // Cache all available voices for gender-based selection later.
    try {
      final dynamic raw = await _tts.getVoices;
      if (raw is List) {
        _voices = raw
            .whereType<Map>()
            .map((v) => v.map((k, val) => MapEntry(k.toString(), val.toString())))
            .toList();
      }
    } catch (_) {
      // getVoices not supported on this engine — gender selection will be skipped.
    }

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

    _isEngineReady = true;
  }

  // ── Voice selection helper ──────────────────────────────────────────────

  /// Tries to find a voice matching [locale] and [voiceType] ('Male'/'Female').
  /// Checks the 'gender' field first, then falls back to the voice name.
  /// Returns null if no matching voice is found (caller keeps current voice).
  Map<String, String>? _findVoice(String locale, String voiceType) {
    if (_voices.isEmpty) return null;
    final wantedGender = voiceType.toLowerCase(); // 'male' or 'female'
    final langCode = locale.split('-')[0].toLowerCase(); // e.g. 'si' from 'si-LK'

    // Filter voices that at least match the language code.
    final localeVoices = _voices.where((v) {
      final vLocale = (v['locale'] ?? '').toLowerCase();
      return vLocale.startsWith(langCode);
    }).toList();

    if (localeVoices.isEmpty) return null;

    // Try matching by gender field (Android usually provides this).
    final byGender = localeVoices.where((v) =>
        (v['gender'] ?? '').toLowerCase() == wantedGender).toList();
    if (byGender.isNotEmpty) return byGender.first;

    // Try matching by voice name containing 'male'/'female'.
    final byName = localeVoices.where((v) =>
        (v['name'] ?? '').toLowerCase().contains(wantedGender)).toList();
    if (byName.isNotEmpty) return byName.first;

    // No gender match — return first available voice for the locale as fallback.
    return localeVoices.first;
  }

  // ── Speak Sinhala (si-LK) ───────────────────────────────────────────────

  Future<void> speakSinhala(
    String text, {
    double speechRate = 0.5,
    String voiceType = 'Female',
  }) async {
    await _tts.stop();
    await _tts.setSpeechRate(speechRate);
    await _tts.setLanguage('si-LK');

    // Try to apply a gender-matching voice for Sinhala.
    final voice = _findVoice('si-LK', voiceType);
    if (voice != null) await _tts.setVoice(voice);

    // Fallback: if Sinhala not supported, use English
    final List<dynamic> langs = await _tts.getLanguages;
    if (!langs.contains('si-LK') && !langs.contains('si')) {
      await _tts.setLanguage('en-US');
      final enVoice = _findVoice('en-US', voiceType);
      if (enVoice != null) await _tts.setVoice(enVoice);
    }
    await _tts.speak(text);
  }

  // ── Speak English (en-US) ───────────────────────────────────────────────

  Future<void> speakEnglish(
    String text, {
    double speechRate = 0.5,
    String voiceType = 'Female',
  }) async {
    await _tts.stop();
    await _tts.setSpeechRate(speechRate);
    await _tts.setLanguage('en-US');
    final voice = _findVoice('en-US', voiceType);
    if (voice != null) await _tts.setVoice(voice);
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

  // ── Error alerts & Language pack check (FR 24 & FR 31) ─────────────────

  /// Announces a verbal alert for system failures (FR 31).
  /// Immediately interrupts ongoing playback and speaks the error message clearly.
  Future<void> announceError(String message, {String? errorCode}) async {
    debugPrint('[Spoken Error Alert] Code: $errorCode | Message: $message');
    await stop();
    final alertText = errorCode != null ? 'Error $errorCode: $message' : message;
    await speakEnglish(alertText, speechRate: 0.5);
  }

  /// Verifies if Sinhala language pack is installed.
  /// If missing, announces a spoken verbal warning to the user (FR 24).
  Future<bool> verifySinhalaVoicePack() async {
    if (!_isSinhalaSupported) {
      await announceError(
        'Sinhala voice engine language pack is not installed on this device. Switching to default English voice.',
        errorCode: 'ERR_LANG_PACK',
      );
      return false;
    }
    return true;
  }
}
