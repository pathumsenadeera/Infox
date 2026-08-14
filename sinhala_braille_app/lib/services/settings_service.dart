import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sinhala_braille_app/services/auth_service.dart';

class SettingsService {
  static const String _baseUrl = AuthService.baseUrl;

  /// Fetches settings for [userId] from the backend.
  /// Returns the settings map on success, or null on failure.
  static Future<Map<String, dynamic>?> getSettings(int userId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/settings/$userId'),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15));

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
      final response = await http
          .put(
            Uri.parse('$_baseUrl/settings/'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "user_id": userId,
              "speech_rate": speechRate,
              "voice_type": voiceType,
              "haptic_vibration": hapticVibration,
            }),
          )
          .timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
