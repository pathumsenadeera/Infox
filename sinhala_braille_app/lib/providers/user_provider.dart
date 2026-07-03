import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String _userName = 'John Doe';
  String _userEmail = 'john@email.com';
  String _password = '1234';

  UserNotifier() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString('user_name') ?? 'John Doe';
    _userEmail = prefs.getString('user_email') ?? 'john@email.com';
    _password = prefs.getString('user_password') ?? '1234';
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _userName);
    await prefs.setString('user_email', _userEmail);
    await prefs.setString('user_password', _password);
  }

  String get userName => _userName;
  String get userEmail => _userEmail;
  String get password => _password;

  void updateProfile(String name) {
    if (name.isNotEmpty && name != _userName) {
      _userName = name;
      _saveToPrefs();
      notifyListeners();
    }
  }

  void updatePassword(String newPassword) {
    if (newPassword.isNotEmpty && newPassword != _password) {
      _password = newPassword;
      _saveToPrefs();
      notifyListeners();
    }
  }

  void signup({
    required String username,
    required String email,
    required String password,
  }) {
    _userName = username;
    _userEmail = email;
    _password = password;
    _saveToPrefs();
    notifyListeners();
  }

  bool login(String usernameOrEmail, String inputPassword) {
    // Matches logged in/created user or default demo account ('admin' / '1234')
    final bool isUserMatch =
        (usernameOrEmail == _userName ||
            usernameOrEmail == _userEmail ||
            usernameOrEmail == 'admin');
    return isUserMatch && inputPassword == _password;
  }
}
