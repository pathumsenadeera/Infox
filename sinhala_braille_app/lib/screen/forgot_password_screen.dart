import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sinhala_braille_app/providers/tts_input_mixin.dart';
import 'package:sinhala_braille_app/screen/login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with TtsInputMixin {
  final TextEditingController _emailController = TextEditingController();

  bool _emailSent = false; // step 1 or step 2 pennanna

  void _onVoiceInput() => startVoiceDictation(_emailController);
  void _onSpeak(String label) => speakLabel(label);

  void _onContinue() {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address!')),
      );
      return;
    }

    // Email format basic check
    if (!_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address!')),
      );
      return;
    }

    // Backend API call - email verification + reset link send
    // Implementation 2 ekedi real API call karanna
    setState(() {
      _emailSent = true;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
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
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                      );
                    },
                    icon: Icon(Icons.arrow_back_sharp, size: 30),
                    style: ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(
                        Colors.grey.shade300,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'FORGOT\nPASSWORD',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 30,
                ),
                child:
                    _emailSent ? _buildEmailSentView() : _buildEmailInputView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Step 1 - Email enter karanna
  Widget _buildEmailInputView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info text
        Text(
          'Enter your registered email address.',
          style: GoogleFonts.poppins(fontSize: 16, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        Text(
          'We will send a password reset link to your email.',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black45),
        ),

        const SizedBox(height: 30),

        // Email input field - mic + speaker icons ekka
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'Enter Email Address',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  // Mic button
                  GestureDetector(
                    onTap: _onVoiceInput,
                    child: Container(
                      width: 46,
                      height: 46,
                      margin: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF7B4FE0),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  // Speaker button
                  GestureDetector(
                    onTap: () => _onSpeak('Enter Email Address'),
                    child: Container(
                      width: 46,
                      height: 46,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF7B4FE0),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.volume_up,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),

        // CONTINUE button
        SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B4FE0),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _onContinue,
            child: Text(
              'CONTINUE',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Step 2 - Email sent confirmation view
  Widget _buildEmailSentView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 30),

        // Success icon
        Container(
          width: 100,
          height: 100,
          decoration: const BoxDecoration(
            color: Color(0xFF7B4FE0),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            size: 52,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 24),

        Text(
          'Reset Link Sent!',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'A password reset link has been sent to:',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
        ),

        const SizedBox(height: 8),

        // Email display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _emailController.text,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF7B4FE0),
            ),
          ),
        ),

        const SizedBox(height: 16),

        Text(
          'Please check your inbox and follow the link to reset your password.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.black45),
        ),

        const SizedBox(height: 40),

        // Resend button
        SizedBox(
          width: double.infinity,
          height: 64,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF7B4FE0), width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              setState(() {
                _emailSent = false;
              });
            },
            child: Text(
              'RESEND LINK',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF7B4FE0),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Back to login button
        SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B4FE0),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: Text(
              'BACK TO LOGIN',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
