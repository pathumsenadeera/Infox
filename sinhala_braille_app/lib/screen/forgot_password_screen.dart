import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sinhala_braille_app/providers/tts_input_mixin.dart';
import 'package:sinhala_braille_app/services/password_recovery_service.dart';
import 'package:sinhala_braille_app/utils/registration_validation.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.service = const PasswordRecoveryService(),
  });
  final PasswordRecoveryService service;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TtsInputMixin {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _emailFocus = FocusNode();
  final _codeFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _codeRequested = false;
  bool _complete = false;
  bool _busy = false;
  bool _showPassword = false;
  String _requestedEmail = '';
  String _message = '';
  Timer? _timer;
  DateTime? _resendAt;
  int _remaining = 0;

  void _showMessage(String message, [FocusNode? focus]) {
    setState(() => _message = message);
    focus?.requestFocus();
    speakLabel(message);
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    _resendAt = DateTime.now().add(Duration(seconds: seconds));
    _remaining = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining =
          (_resendAt!.difference(DateTime.now()).inMilliseconds / 1000).ceil();
      setState(() => _remaining = remaining > 0 ? remaining : 0);
      if (_remaining == 0) timer.cancel();
    });
  }

  Future<void> _requestCode() async {
    if (_busy || _remaining > 0) return;
    final email = _codeRequested ? _requestedEmail : _email.text.trim();
    if (!isValidRegistrationEmail(email)) {
      _showMessage('Please enter a valid email address.', _emailFocus);
      return;
    }
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      final result = await widget.service.requestCode(email);
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() {
          _requestedEmail = email;
          _codeRequested = true;
          _code.clear();
          _startCooldown(
            result['resend_after_seconds'] is int
                ? result['resend_after_seconds'] as int
                : 60,
          );
        });
        _showMessage(
          result['message'] as String? ??
              'If this email is registered, a code will arrive shortly.',
        );
      } else {
        _showMessage(
          result['message'] as String? ??
              'Could not request a code. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) _showMessage('Could not connect. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_busy) return;
    final code = _code.text.trim();
    if (!RegExp(r'^[0-9]{8}$').hasMatch(code)) {
      _showMessage('Enter the eight-digit code from your email.', _codeFocus);
      return;
    }
    final password = _password.text;
    if (password.isEmpty) {
      _showMessage('Please enter your new password.', _passwordFocus);
      return;
    }
    if (utf8.encode(password).length > 72 || password.contains('\u0000')) {
      _showMessage(
        'This password is too long or contains an unsupported character.',
        _passwordFocus,
      );
      return;
    }
    if (password != _confirm.text) {
      _showMessage('Passwords do not match.', _confirmFocus);
      return;
    }
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      final result = await widget.service.resetPassword(
        _requestedEmail,
        code,
        password,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        _timer?.cancel();
        _code.clear();
        _password.clear();
        _confirm.clear();
        FocusScope.of(context).unfocus();
        setState(() => _complete = true);
        _showMessage(
          'Password reset successfully. Log in with your new password.',
        );
      } else {
        _showMessage(
          result['message'] as String? ??
              'Could not reset your password. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) _showMessage('Could not connect. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _backToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in [_email, _code, _password, _confirm]) {
      controller.dispose();
    }
    for (final focus in [
      _emailFocus,
      _codeFocus,
      _passwordFocus,
      _confirmFocus,
    ]) {
      focus.dispose();
    }
    super.dispose();
  }

  Widget _field(
    String label,
    TextEditingController controller,
    FocusNode focus, {
    bool password = false,
    bool code = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              enabled: !_busy,
              obscureText: password && !_showPassword,
              autocorrect: false,
              enableSuggestions: !password && !code,
              keyboardType:
                  code
                      ? TextInputType.number
                      : password
                      ? TextInputType.visiblePassword
                      : TextInputType.emailAddress,
              autofillHints:
                  code
                      ? const [AutofillHints.oneTimeCode]
                      : password
                      ? const [AutofillHints.newPassword]
                      : const [AutofillHints.email],
              inputFormatters:
                  code
                      ? [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ]
                      : null,
              decoration: InputDecoration(
                labelText: label,
                filled: true,
                fillColor: const Color(0xFFE4E4E4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (!password && !code)
            IgnorePointer(ignoring: _busy, child: buildMicButton(controller)),
          buildSpeakerButton(label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B4FE0),
        foregroundColor: Colors.white,
        title: Text(
          'FORGOT PASSWORD',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _busy ? null : _backToLogin,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _message,
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                  ),
                ),
              if (_complete) ...[
                const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF7B4FE0),
                  size: 72,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _backToLogin,
                  child: const Text('BACK TO LOGIN'),
                ),
              ] else if (!_codeRequested) ...[
                const Text(
                  'Enter your registered email address to request a password reset code.',
                ),
                const SizedBox(height: 24),
                _field('Email address', _email, _emailFocus),
                ElevatedButton(
                  onPressed: _busy ? null : _requestCode,
                  child: const Text('SEND CODE'),
                ),
              ] else ...[
                Text('Email: $_requestedEmail'),
                const SizedBox(height: 12),
                const Text(
                  'Enter the eight-digit code and choose a new password. Codes expire after 10 minutes. Only the latest code works.',
                ),
                const SizedBox(height: 24),
                _field('Reset code', _code, _codeFocus, code: true),
                _field(
                  'New password',
                  _password,
                  _passwordFocus,
                  password: true,
                ),
                _field(
                  'Confirm new password',
                  _confirm,
                  _confirmFocus,
                  password: true,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show passwords'),
                  value: _showPassword,
                  onChanged:
                      _busy
                          ? null
                          : (value) =>
                              setState(() => _showPassword = value ?? false),
                ),
                ElevatedButton(
                  onPressed: _busy ? null : _resetPassword,
                  child: const Text('RESET PASSWORD'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busy || _remaining > 0 ? null : _requestCode,
                  child: Text(
                    _remaining > 0
                        ? 'RESEND CODE IN ${_remaining}s'
                        : 'RESEND CODE',
                  ),
                ),
                const Text(
                  'You can request up to five codes per hour. If no email arrives, check spam and try again later.',
                ),
                TextButton(
                  onPressed:
                      _busy
                          ? null
                          : () {
                            _timer?.cancel();
                            _code.clear();
                            _password.clear();
                            _confirm.clear();
                            setState(() {
                              _codeRequested = false;
                              _remaining = 0;
                              _message = '';
                            });
                          },
                  child: const Text('USE A DIFFERENT EMAIL'),
                ),
              ],
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
