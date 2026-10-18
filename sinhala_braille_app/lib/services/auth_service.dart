import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:sinhala_braille_app/services/session_service.dart';

class AuthService {
  static const baseUrl = SessionService.baseUrl;
  static SessionService get _session => SessionService.instance;

  static Future<Map<String, dynamic>> _perform(
    Future<http.Response> Function() action,
  ) async {
    try {
      final response = await action();
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {...data, 'success': true};
      }
      return {
        'success': false,
        'status_code': response.statusCode,
        'retry_after_seconds': int.tryParse(
          response.headers['retry-after'] ?? '',
        ),
        'message':
            data['detail'] is String
                ? data['detail']
                : 'Please check your input.',
      };
    } on SessionExpired {
      return {
        'success': false,
        'message': 'Session expired. Please log in again.',
      };
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Connection timed out. Please try again.',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Could not connect to the server. Please try again.',
      };
    }
  }

  static Future<Map<String, dynamic>> signup(
    String username,
    String email,
    String password,
  ) => _perform(
    () => _session.publicRequest(
      'POST',
      '/signup',
      body: {'username': username, 'email': email, 'password': password},
    ),
  );

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final result = await _perform(
      () => _session.publicRequest(
        'POST',
        '/login',
        body: {'username': username, 'password': password},
      ),
    );
    if (result['success'] == true) {
      try {
        await _session.acceptLogin(result);
      } on PlatformException {
        return {
          'success': false,
          'message': 'Could not securely store your session. Please try again.',
        };
      } catch (_) {
        return {
          'success': false,
          'message':
              'The server returned an invalid session. Please update the backend.',
        };
      }
    }
    return result;
  }

  static Future<Map<String, dynamic>> updateUsername(
    String userId,
    String newUsername,
  ) => _perform(
    () => _session.request(
      'PUT',
      '/update-username',
      body: {'user_id': int.parse(userId), 'new_username': newUsername},
    ),
  );

  static Future<Map<String, dynamic>> changePassword(
    String userId,
    String currentPassword,
    String newPassword,
  ) => _perform(
    () => _session.request(
      'PUT',
      '/change-password',
      body: {
        'user_id': int.parse(userId),
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    ),
  );
}
