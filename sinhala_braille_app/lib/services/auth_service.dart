import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  // Replace with your actual Azure VM IP address
  static const String baseUrl = "http://20.40.50.154:8000";

  static Future<Map<String, dynamic>> signup(String username, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "email": email,
          "password": password,
        }),
      );

      if (response.statusCode == 201) {
        return {"success": true, "message": "Registered successfully"};
      } else {
        final errorData = jsonDecode(response.body);
        return {"success": false, "message": errorData['detail']};
      }
    } catch (e) {
      return {"success": false, "message": "Network error: Could not connect to server"};
    }
  }

  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "password": password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {"success": true, "user_id": data['user_id']};
      } else {
        return {"success": false, "message": "Invalid username or password"};
      }
    } catch (e) {
      return {"success": false, "message": "Network error: Could not connect to server"};
    }
  }
}