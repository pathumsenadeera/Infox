import 'package:flutter/material.dart';

/// Global settings state shared across all screens.
/// Persists speech rate, voice type, and haptic preference
/// for the lifetime of the app session.
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
  double _speechRate = 1.5;
  String _voiceType = 'Male';
  bool _hapticOn = true;

  double get speechRate => _speechRate;
  String get voiceType => _voiceType;
  bool get hapticOn => _hapticOn;

  void setSpeechRate(double rate) {
    final clamped = rate.clamp(0.5, 3.0);
    if (clamped != _speechRate) {
      _speechRate = clamped;
      notifyListeners();
    }
  }

  void setVoiceType(String type) {
    if (type != _voiceType) {
      _voiceType = type;
      notifyListeners();
    }
  }

  void setHaptic(bool value) {
    if (value != _hapticOn) {
      _hapticOn = value;
      notifyListeners();
    }
  }
}
