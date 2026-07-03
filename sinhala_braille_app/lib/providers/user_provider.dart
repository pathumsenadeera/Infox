import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinhala_braille_app/services/auth_service.dart';

/// Global user state shared across authentication and profile screens.
class UserProvider extends InheritedNotifier<UserNotifier> {
  const UserProvider({
    super.key,
    required UserNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static UserNotifier of(BuildContext context) {
    final result =
        context.dependOnInheritedWidgetOfExactType<UserProvider>()?.notifier;
    assert(result != null, 'No UserProvider found in context');
    return result!;
  }
}

class UserNotifier extends ChangeNotifier {
  String _userName = '';
  String _userEmail = '';
  String _password = '';
  String? _userId;

  UserNotifier() {
    _loadFromPrefs();
  }

  // ── Persistence ─────────────────────────────────────────────────────────

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString('user_name') ?? '';
    _userEmail = prefs.getString('user_email') ?? '';
    _password = prefs.getString('user_password') ?? '';
    _userId = prefs.getString('user_id');
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _userName);
    await prefs.setString('user_email', _userEmail);
    await prefs.setString('user_password', _password);
    if (_userId != null) await prefs.setString('user_id', _userId!);
  }

  // ── Getters ──────────────────────────────────────────────────────────────

  String get userName => _userName;
  String get userEmail => _userEmail;
  String get password => _password;
  String? get userId => _userId;

  // ── Auth (API) ───────────────────────────────────────────────────────────

  /// Calls the backend signup endpoint.
  Future<Map<String, dynamic>> signup({
    required String username,
    required String email,
    required String password,
  }) async {
    final result = await AuthService.signup(username, email, password);
    if (result['success'] == true) {
      _userName = username;
      _userEmail = email;
      _userId = null;
      await _saveToPrefs();
      notifyListeners();
    }
    return result;
  }

  /// Calls the backend login endpoint.
  Future<Map<String, dynamic>> login(String username, String password) async {
    final result = await AuthService.login(username, password);
    if (result['success'] == true) {
      _userName = username;
      _password = password;
      _userId = result['user_id']?.toString();
      await _saveToPrefs();
      notifyListeners();
    }
    return result;
  }

  // ── Profile mutations (API-backed) ───────────────────────────────────────

  /// Calls PUT /update-username on the server, then updates local state.
  Future<Map<String, dynamic>> updateUsername(String newName) async {
    if (newName.isEmpty || newName == _userName) {
      return {"success": false, "message": "Name is unchanged or empty"};
    }
    if (_userId == null) {
      return {"success": false, "message": "Not logged in"};
    }
    final result = await AuthService.updateUsername(_userId!, newName);
    if (result['success'] == true) {
      _userName = newName;
      await _saveToPrefs();
      notifyListeners();
    }
    return result;
  }

  /// Calls PUT /change-password on the server after local confirmation check,
  /// then updates the locally cached password.
  Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (_userId == null) {
      return {"success": false, "message": "Not logged in"};
    }
    final result = await AuthService.changePassword(
      _userId!,
      currentPassword,
      newPassword,
    );
    if (result['success'] == true) {
      _password = newPassword;
      await _saveToPrefs();
      notifyListeners();
    }
    return result;
  }
}
