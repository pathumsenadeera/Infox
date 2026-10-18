import 'package:flutter/material.dart';
import 'package:sinhala_braille_app/services/session_service.dart';
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
  UserNotifier({SessionService? session})
    : _session = session ?? SessionService.instance {
    _session.addListener(notifyListeners);
    ready = _session.initialize();
  }
  final SessionService _session;
  late Future<void> ready;
  Future<void> restore() => ready = _session.initialize();
  bool get isSignedIn => _session.isSignedIn;
  String get userName => _session.username;
  String get userEmail => _session.email;
  String? get userId => _session.userId;

  Future<Map<String, dynamic>> signup({
    required String username,
    required String email,
    required String password,
  }) => AuthService.signup(username, email, password);

  Future<Map<String, dynamic>> login(String username, String password) async {
    await ready;
    return AuthService.login(username, password);
  }

  Future<Map<String, dynamic>> updateUsername(String newName) async {
    if (userId == null) return {'success': false, 'message': 'Not logged in'};
    final result = await AuthService.updateUsername(userId!, newName);
    if (result['success'] == true) await _session.updateUsername(newName);
    return result;
  }

  Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (userId == null) return {'success': false, 'message': 'Not logged in'};
    final result = await AuthService.changePassword(
      userId!,
      currentPassword,
      newPassword,
    );
    if (result['success'] == true) await _session.clear();
    return result;
  }

  Future<void> logout() => _session.logout();

  @override
  void dispose() {
    _session.removeListener(notifyListeners);
    super.dispose();
  }
}
