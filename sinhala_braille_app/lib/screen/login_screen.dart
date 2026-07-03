import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sinhala_braille_app/providers/tts_input_mixin.dart';
import 'package:sinhala_braille_app/providers/user_provider.dart';
import 'package:sinhala_braille_app/screen/assistive_reader_screen.dart';
import 'package:sinhala_braille_app/screen/auth_screen.dart';
import 'package:sinhala_braille_app/screen/forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TtsInputMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;

  // ── Lockout state machine ───────────────────────────────────────────────
  int _failedAttempts = 0;
  static const int _maxAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 15);
  DateTime? _lockoutUntil;
  Timer? _lockoutTimer;
  int _lockoutSecondsRemaining = 0;

  bool get _isLockedOut {
    if (_lockoutUntil == null) return false;
    return DateTime.now().isBefore(_lockoutUntil!);
  }

  void _startLockoutCountdown() {
    _lockoutTimer?.cancel();
    _lockoutSecondsRemaining =
        _lockoutUntil!.difference(DateTime.now()).inSeconds;
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final remaining = _lockoutUntil!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        t.cancel();
        setState(() {
          _lockoutUntil = null;
          _failedAttempts = 0;
          _lockoutSecondsRemaining = 0;
        });
      } else {
        setState(() => _lockoutSecondsRemaining = remaining);
      }
    });
  }

  String _formatLockoutTime() {
    final m = (_lockoutSecondsRemaining ~/ 60).toString().padLeft(2, '0');
    final s = (_lockoutSecondsRemaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
  // ────────────────────────────────────────────────────────────────────────

  void _onLogin() async {
    // Check lockout first
    if (_isLockedOut) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account locked. Try again in ${_formatLockoutTime()}.',
          ),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Call the API via UserNotifier (which wraps AuthService)
    final result = await UserProvider.of(context).login(username, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    // 3. handle success
    if (result['success'] == true) {
      _failedAttempts = 0;
      _lockoutTimer?.cancel();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AssistiveReaderScreen()),
      );
    }
    // 4. handle failure and lockout
    else {
      _failedAttempts++;
      final remaining = _maxAttempts - _failedAttempts;

      if (_failedAttempts >= _maxAttempts) {
        //Trigger Lockout
        setState(() {
          _lockoutUntil = DateTime.now().add(_lockoutDuration);
        });
        _startLockoutCountdown();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Too many failed attempts. Account locked for 15 minutes.',
            ),
            backgroundColor: Colors.red[800],
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        final message =
            result['message'] as String? ?? 'Invalid username or password.';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$message ($remaining attempt${remaining == 1 ? '' : 's'} remaining)',
            ),
            backgroundColor: Colors.orange[700],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Purple header
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF7B4FE0),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              padding: const EdgeInsets.only(
                top: 20,
                bottom: 30,
                left: 20,
                right: 20,
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AuthScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.arrow_back_sharp, size: 30),
                          style: ButtonStyle(
                            backgroundColor: WidgetStatePropertyAll(
                              Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Image.asset(
                            'assets/image/infox_white.png',
                            width: 55,
                            height: 55,
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'LOGIN',
                    style: GoogleFonts.poppins(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                child: Column(
                  children: [
                    // Lockout banner
                    if (_isLockedOut)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 18),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_clock,
                              color: Colors.red[700],
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Account locked for 15 minutes.\nTime remaining: ${_formatLockoutTime()}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red[800],
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    _buildInputField(
                      controller: _usernameController,
                      label: 'UserName',
                      fieldName: 'Username',
                    ),
                    const SizedBox(height: 18),
                    _buildInputField(
                      controller: _passwordController,
                      label: 'Password',
                      fieldName: 'Password',
                      isPassword: true,
                      isVisible: _showPassword,
                      onToggleVisibility: () {
                        setState(() {
                          _showPassword = !_showPassword;
                        });
                      },
                    ),
                    const SizedBox(height: 18),

                    // Forgot Password row
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4E4E4),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'Forgot Password',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => speakLabel('Forgot Password'),
                            child: const Icon(
                              Icons.volume_up,
                              color: Color(0xFF7B4FE0),
                              size: 35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 80,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isLockedOut || _isLoading
                                  ? Colors.grey
                                  : const Color(0xFF7B4FE0),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed:
                            (_isLockedOut || _isLoading) ? null : _onLogin,
                        child:
                            _isLoading
                                ? const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                )
                                : Text(
                                  _isLockedOut
                                      ? 'LOCKED - ${_formatLockoutTime()}'
                                      : 'Login',
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignupScreen(),
                          ),
                        );
                      },
                      child: Text(
                        "Don't have an Account?",
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String fieldName,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onToggleVisibility,
  }) {
    return Container(
      height: 78,
      decoration: BoxDecoration(
        color: const Color(0xFFE4E4E4),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: isPassword && !isVisible,
              style: GoogleFonts.poppins(fontSize: 17, color: Colors.black87),
              decoration: InputDecoration(
                hintText: label,
                border: InputBorder.none,
                hintStyle: GoogleFonts.poppins(
                  fontSize: 17,
                  color: Colors.black54,
                ),
              ),
            ),
          ),
          if (isPassword && onToggleVisibility != null)
            GestureDetector(
              onTap: onToggleVisibility,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  isVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey[700],
                  size: 24,
                ),
              ),
            ),
          buildMicButton(controller),
          buildSpeakerButton(label),
        ],
      ),
    );
  }
}
