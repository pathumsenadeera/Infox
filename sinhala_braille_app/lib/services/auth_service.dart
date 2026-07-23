import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  // Replace with your actual Azure VM IP address
  static const String baseUrl = "https://server.projectinfox.tech";

  // ── Auth ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> signup(
    String username,
    String email,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/signup'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "username": username,
              "email": email,
              "password": password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        return {"success": true, "message": "Registered successfully"};
      } else {
        final errorData = jsonDecode(response.body);
        return {"success": false, "message": errorData['detail']};
      }
    } on TimeoutException {
      return {
        "success": false,
        "message": "Connection timed out. Please try again.",
      };
    } catch (e) {
      return {
        "success": false,
        "message": "Network error: Could not connect to server",
      };
    }
  }

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"username": username, "password": password}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {"success": true, "user_id": data['user_id']};
      } else {
        return {"success": false, "message": "Invalid username or password"};
      }
    } on TimeoutException {
      return {
        "success": false,
        "message": "Connection timed out. Please try again.",
      };
    } catch (e) {
      return {
        "success": false,
        "message": "Network error: Could not connect to server",
      };
    }
  }

  // ── Profile ──────────────────────────────────────────────────────────────

  /// Updates the username for [userId] on the server.
  static Future<Map<String, dynamic>> updateUsername(
    String userId,
    String newUsername,
  ) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/update-username'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "user_id": int.parse(userId),
              "new_username": newUsername,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return {"success": true, "message": "Username updated successfully"};
      } else {
        final errorData = jsonDecode(response.body);
        return {
          "success": false,
          "message": errorData['detail'] ?? "Failed to update username",
        };
      }
    } on TimeoutException {
      return {
        "success": false,
        "message": "Connection timed out. Please try again.",
      };
    } catch (e) {
      return {
        "success": false,
        "message": "Network error: Could not connect to server",
      };
    }
  }

  /// Changes the password for [userId] after verifying [currentPassword].
  static Future<Map<String, dynamic>> changePassword(
    String userId,
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/change-password'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "user_id": int.parse(userId),
              "current_password": currentPassword,
              "new_password": newPassword,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return {"success": true, "message": "Password changed successfully"};
      } else {
        final errorData = jsonDecode(response.body);
        return {
          "success": false,
          "message": errorData['detail'] ?? "Failed to change password",
        };
      }
    } on TimeoutException {
      return {
        "success": false,
        "message": "Connection timed out. Please try again.",
      };
    } catch (e) {
      return {
        "success": false,
        "message": "Network error: Could not connect to server",
      };
    }
  }
}
