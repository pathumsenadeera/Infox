import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sinhala_braille_app/providers/user_provider.dart';
import 'package:sinhala_braille_app/screen/assistive_reader_screen.dart';
import 'package:sinhala_braille_app/screen/auth_screen.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _showPassword = false;
  bool _showConfirmPassword = false;
  double _passwordStrengthScore = 0.0;
  String _passwordStrengthLabel = '';
  Color _passwordStrengthColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_checkPasswordStrength);
  }

  void _checkPasswordStrength() {
    final pass = _passwordController.text;
    if (pass.isEmpty) {
      setState(() {
        _passwordStrengthScore = 0.0;
        _passwordStrengthLabel = '';
      });
      return;
    }
    int score = 0;
    if (pass.length >= 6) score++;
    if (pass.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(pass) && RegExp(r'[a-z]').hasMatch(pass)) {
      score++;
    }
    if (RegExp(r'[0-9]').hasMatch(pass)) score++;
    if (RegExp(r'[!@#\$&*~`()%^_+=|{}\[\]:;<>,.?/]').hasMatch(pass)) score++;

    setState(() {
      if (score <= 2) {
        _passwordStrengthScore = 0.33;
        _passwordStrengthLabel = 'Weak';
        _passwordStrengthColor = Colors.red;
      } else if (score <= 4) {
        _passwordStrengthScore = 0.66;
        _passwordStrengthLabel = 'Medium';
        _passwordStrengthColor = Colors.orange;
      } else {
        _passwordStrengthScore = 1.0;
        _passwordStrengthLabel = 'Strong';
        _passwordStrengthColor = Colors.green;
      }
    });
  }

  void _onVoiceInput(String field) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$field voice input - coming soon')));
  }

  void _onSpeak(String text) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Speaking: $text')));
  }

  void _onSignUp() {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    // Email validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }

    // Confirm password match check
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match!')),
      );
      return;
    }

    // Save user state
    UserProvider.of(
      context,
    ).signup(username: username, email: email, password: password);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account Created Successfully!')),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => AssistiveReaderScreen()),
    );
  }

  @override
  void dispose() {
    _passwordController.removeListener(_checkPasswordStrength);
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Purple header section - rounded bottom corners
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
                  // Back button - top left, logo - center
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
                                builder: (context) => AuthScreen(),
                              ),
                            );
                          },
                          icon: Icon(Icons.arrow_back_sharp, size: 30),
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
                    'CREATE\nACCOUNT',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),

            // Form fields
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                child: Column(
                  children: [
                    _buildInputField(
                      controller: _usernameController,
                      label: 'UserName',
                      fieldName: 'Username',
                    ),
                    const SizedBox(height: 18),
                    _buildInputField(
                      controller: _emailController,
                      label: 'E-mail',
                      fieldName: 'Email',
                      keyboardType: TextInputType.emailAddress,
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
                    if (_passwordStrengthLabel.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _passwordStrengthScore,
                                  backgroundColor: Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _passwordStrengthColor,
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _passwordStrengthLabel,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _passwordStrengthColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    _buildInputField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      fieldName: 'Confirm Password',
                      isPassword: true,
                      isVisible: _showConfirmPassword,
                      onToggleVisibility: () {
                        setState(() {
                          _showConfirmPassword = !_showConfirmPassword;
                        });
                      },
                    ),
                    const SizedBox(height: 28),

                    // Sign Up button
                    SizedBox(
                      width: double.infinity,
                      height: 80,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B4FE0),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _onSignUp,
                        child: Text(
                          'Sign Up',
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
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Already have an Account?',
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

  // Input field - label + mic icon + speaker icon (image eke widiyatama)
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String fieldName,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onToggleVisibility,
    TextInputType keyboardType = TextInputType.text,
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
              keyboardType: keyboardType,
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
          // Microphone (voice input) button
          GestureDetector(
            onTap: () => _onVoiceInput(fieldName),
            child: Container(
              width: 52,
              height: 52,
              margin: const EdgeInsets.only(left: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF7B4FE0),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 24),
            ),
          ),
          // Speaker (TTS read label) button
          GestureDetector(
            onTap: () => _onSpeak(label),
            child: Container(
              width: 52,
              height: 52,
              margin: const EdgeInsets.only(left: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF7B4FE0),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.volume_up, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
