import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinhala_braille_app/providers/app_settings_provider.dart';
import 'package:sinhala_braille_app/providers/tts_service.dart';
import 'package:sinhala_braille_app/providers/user_provider.dart';
import 'package:sinhala_braille_app/screen/assistive_reader_screen.dart';
import 'package:sinhala_braille_app/screen/welcome_screen.dart';

// Global list to store available cameras
List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("Error fetching cameras: $e");
  }

  // Initialise TTS + STT service
  //add loading screen or something because this takes 5-6 seconds to load.
  await TtsService.instance.init();

  runApp(
    AppSettings(
      notifier: AppSettingsNotifier(),
      child: UserProvider(notifier: UserNotifier(), child: const MyApp()),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// Cached Future — created once in initState so it never re-fires
  /// when Flutter rebuilds MyApp (e.g. when returning from recent apps).
  late final Future<bool> _loginCheckFuture;

  @override
  void initState() {
    super.initState();
    _loginCheckFuture = _isLoggedIn();
  }

  /// Reads SharedPreferences once to decide whether the user is already
  /// logged in (user_id saved) or should see the welcome/auth flow.
  static Future<bool> _isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    return userId != null && userId.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InfoX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7B4FE0)),
        textTheme: GoogleFonts.poppinsTextTheme(),
        useMaterial3: true,
      ),
      home: FutureBuilder<bool>(
        future: _loginCheckFuture,
        builder: (context, snapshot) {
          // Show a splash while we read prefs (< 50 ms typically)
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              backgroundColor: Color(0xFF0c031f),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF7B4FE0)),
              ),
            );
          }

          final loggedIn = snapshot.data ?? false;
          return loggedIn
              ? const AssistiveReaderScreen()
              : const WelcomeScreen();
        },
      ),
    );
  }
}
