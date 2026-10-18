import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sinhala_braille_app/screen/login_screen.dart';
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

  // Start TTS + STT initialisation in the background.
  // Removing the await means the app launches immediately instead of hanging
  // for 5–6 s on the blank screen. TtsService guards all speak/listen calls
  // via _isEngineReady so nothing breaks while init is still in progress.
  TtsService.instance.init();

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
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  UserNotifier? _user;
  Future<void>? _initialization;
  String? _previousUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = UserProvider.of(context);
    if (identical(user, _user)) return;
    _user?.removeListener(_onSessionChanged);
    _user = user;
    _previousUserId = user.userId;
    user.addListener(_onSessionChanged);
    _initialization = _restore(user.ready);
  }

  Future<void> _restore(Future<void> ready) async {
    await ready;
    if (!mounted || _user?.userId == null) return;
    await AppSettings.of(context).loadFromServer(int.parse(_user!.userId!));
  }

  void _onSessionChanged() {
    final wasSignedIn = _previousUserId != null;
    _previousUserId = _user?.userId;
    if (wasSignedIn && _previousUserId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _user!.isSignedIn) return;
        TtsService.instance.stop();
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
        _messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Please log in to continue.')),
        );
      });
    }
  }

  @override
  void dispose() {
    _user?.removeListener(_onSessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InfoX',
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7B4FE0)),
        textTheme: GoogleFonts.poppinsTextTheme(),
        useMaterial3: true,
      ),
      home: FutureBuilder<void>(
        future: _initialization,
        builder: (context, snapshot) {
          // Wait for secure storage and the initial server session check.
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              backgroundColor: Color(0xFF0c031f),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF7B4FE0)),
              ),
            );
          }

          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not restore your secure session.'),
                    ElevatedButton(
                      onPressed: () {
                        setState(
                          () => _initialization = _restore(_user!.restore()),
                        );
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final loggedIn = _user!.isSignedIn;
          return loggedIn
              ? const AssistiveReaderScreen()
              : const WelcomeScreen();
        },
      ),
    );
  }
}
