import 'auth_service.dart';

class PasswordRecoveryService {
  const PasswordRecoveryService();

  Future<Map<String, dynamic>> requestCode(String email) =>
      AuthService.requestPasswordReset(email);

  Future<Map<String, dynamic>> resetPassword(
    String email,
    String code,
    String password,
  ) => AuthService.confirmPasswordReset(email, code, password);
}
