import 'dart:async';
import 'dart:convert';
import 'package:sinhala_braille_app/services/session_service.dart';

class SettingsService {
  /// Fetches settings for [userId] from the backend.
  /// Returns the settings map on success, or null on failure.
  static Future<Map<String, dynamic>?> getSettings(int userId) async {
    try {
      final response = await SessionService.instance.request(
        'GET',
        '/settings/$userId',
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Saves (insert or update) settings for [userId] to the backend.
  /// Returns true on success.
  static Future<bool> saveSettings({
    required int userId,
    required double speechRate,
    required String voiceType,
    required bool hapticVibration,
  }) async {
    try {
      final response = await SessionService.instance.request(
        'PUT',
        '/settings/',
        body: {
          'user_id': userId,
          'speech_rate': speechRate,
          'voice_type': voiceType,
          'haptic_vibration': hapticVibration,
        },
      );

      return response.statusCode == 200;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
