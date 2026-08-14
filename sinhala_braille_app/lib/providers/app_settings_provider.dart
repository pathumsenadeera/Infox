import 'package:flutter/material.dart';
import 'package:sinhala_braille_app/services/settings_service.dart';

/// Global settings state shared across all screens.
/// Persists speech rate, voice type, and haptic preference
/// both in-memory for the session and remotely via the backend API.
class AppSettings extends InheritedNotifier<AppSettingsNotifier> {
  const AppSettings({
    super.key,
    required AppSettingsNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static AppSettingsNotifier of(BuildContext context) {
    final result =
        context.dependOnInheritedWidgetOfExactType<AppSettings>()?.notifier;
    assert(result != null, 'No AppSettings found in context');
    return result!;
  }
}

class AppSettingsNotifier extends ChangeNotifier {
  double _speechRate = 1.0;
  String _voiceType = 'Female';
  bool _hapticOn = true;

  double get speechRate => _speechRate;
  String get voiceType => _voiceType;
  bool get hapticOn => _hapticOn;

  // ── Server sync ──────────────────────────────────────────────────────────

  /// Loads settings from the backend for [userId] and updates local state.
  /// Call this right after login or on app start for a returning user.
  Future<void> loadFromServer(int userId) async {
    final data = await SettingsService.getSettings(userId);
    if (data == null) return; // Silently keep defaults on network failure

    final rate = (data['speech_rate'] as num?)?.toDouble() ?? _speechRate;
    final voice = data['voice_type'] as String? ?? _voiceType;
    // MySQL returns TINYINT as int (1/0), not bool — handle both types safely
    final rawHaptic = data['haptic_vibration'];
    final haptic = rawHaptic is bool ? rawHaptic : (rawHaptic as int?) == 1;

    _speechRate = rate.clamp(0.5, 3.0);
    _voiceType = voice;
    _hapticOn = haptic;
    notifyListeners();
  }

  /// Saves current settings to the backend for [userId].
  Future<void> saveToServer(int userId) async {
    await SettingsService.saveSettings(
      userId: userId,
      speechRate: _speechRate,
      voiceType: _voiceType,
      hapticVibration: _hapticOn,
    );
  }

  // ── Local setters (also persist to server when userId is known) ──────────

  void setSpeechRate(double rate, {int? userId}) {
    // Round to 1 decimal place to avoid floating point drift (e.g. 1.5000000000000004)
    final clamped = double.parse(rate.clamp(0.5, 3.0).toStringAsFixed(1));
    if (clamped != _speechRate) {
      _speechRate = clamped;
      notifyListeners();
      if (userId != null) saveToServer(userId);
    }
  }

  void setVoiceType(String type, {int? userId}) {
    if (type != _voiceType) {
      _voiceType = type;
      notifyListeners();
      if (userId != null) saveToServer(userId);
    }
  }

  void setHaptic(bool value, {int? userId}) {
    if (value != _hapticOn) {
      _hapticOn = value;
      notifyListeners();
      if (userId != null) saveToServer(userId);
    }
  }
}
