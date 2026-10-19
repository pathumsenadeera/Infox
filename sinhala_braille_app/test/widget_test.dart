import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:sinhala_braille_app/screen/live_camera_screen.dart';
import 'camera_capture_preparation_test.dart' show RecordingCamera, back;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as fonts;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinhala_braille_app/main.dart';
import 'package:sinhala_braille_app/providers/app_settings_provider.dart';
import 'package:sinhala_braille_app/providers/user_provider.dart';
import 'package:sinhala_braille_app/services/session_service.dart';
import 'package:sinhala_braille_app/screen/assistive_reader_screen.dart';
import 'package:sinhala_braille_app/screen/login_screen.dart';
import 'package:sinhala_braille_app/screen/welcome_screen.dart';
import 'package:sinhala_braille_app/screen/forgot_password_screen.dart';
import 'package:sinhala_braille_app/services/password_recovery_service.dart';

class _Store implements SessionStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String text) async {
    value = text;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

class _PreviewCamera extends RecordingCamera {
  int captures = 0;
  bool disposed = false;
  final photo = Completer<XFile>();
  @override
  Future<void> initialize() async {
    value = value.copyWith(
      isInitialized: true,
      previewSize: const Size(640, 480),
    );
  }

  @override
  Future<void> setFlashMode(FlashMode mode) async {}
  @override
  Widget buildPreview() => const SizedBox.expand();
  @override
  Future<XFile> takePicture() {
    captures++;
    return photo.future;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await super.dispose();
  }
}

class _Fonts implements AssetManifest {
  @override
  List<String> listAssets() => [
    for (final name in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
      'Light',
      'Thin',
      'ExtraLight',
      'Black',
    ])
      'Poppins-$name.ttf',
  ];
  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

class _LoginUser extends UserNotifier {
  _LoginUser() : super(session: SessionService(store: _Store()));
  int calls = 0;
  Map<String, dynamic> result = {
    'success': false,
    'message': 'Could not connect to the server. Please try again.',
  };

  @override
  Future<Map<String, dynamic>> login(String username, String password) async {
    calls++;
    return result;
  }
}

class _Recovery extends PasswordRecoveryService {
  int requests = 0;
  int resets = 0;
  List<String>? submitted;
  Map<String, dynamic> requestResult = {
    'success': true,
    'message': 'If this email is registered, a code will arrive shortly.',
    'resend_after_seconds': 60,
  };
  Map<String, dynamic> resetResult = {'success': true};

  @override
  Future<Map<String, dynamic>> requestCode(String email) async {
    requests++;
    return requestResult;
  }

  @override
  Future<Map<String, dynamic>> resetPassword(
    String email,
    String code,
    String password,
  ) async {
    resets++;
    submitted = [email, code, password];
    return resetResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fonts.assetManifest = _Fonts();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final key = const StringCodec().decodeMessage(message);
      if (key == 'AssetManifest.bin') {
        return const StandardMessageCodec().encodeMessage(<String, dynamic>{});
      }
      if (key != null && key.endsWith('.ttf')) return ByteData(0);
      if (key != null && File(key).existsSync()) {
        return ByteData.sublistView(File(key).readAsBytesSync());
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (_) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugin.csdcorp.com/speech_to_text'),
      (_) async => true,
    );
  });

  Future<void> open(WidgetTester tester, SessionService session) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final user = UserNotifier(session: session);
    final settings = AppSettingsNotifier();
    addTearDown(user.dispose);
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      AppSettings(
        notifier: settings,
        child: UserProvider(notifier: user, child: const MyApp()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'camera cancels moving/background holds and restarts the full three seconds',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previousCameras = cameras;
      cameras = [back];
      addTearDown(() => cameras = previousCameras);
      final events = StreamController<AccelerometerEvent>.broadcast(sync: true);
      final created = <_PreviewCamera>[];
      await tester.pumpWidget(
        MaterialApp(
          home: LiveCameraScreen(
            cameraFactory: (_) {
              final camera = _PreviewCamera();
              created.add(camera);
              return camera;
            },
            accelerometerEvents: events.stream,
          ),
        ),
      );
      Future<void> warmUp() async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(seconds: 2));
      }

      void sample(double x) =>
          events.add(AccelerometerEvent(x, 0, 9.8, DateTime.now()));
      await warmUp();
      sample(0);
      sample(0);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(created.first.captures, 0);
      sample(1.2); // Movement is below the old tilt limit but resets the hold.
      await tester.pump(const Duration(seconds: 2));
      expect(created.first.captures, 0);
      sample(0);
      sample(0);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      await tester.pump(const Duration(seconds: 4));
      expect(created.first.disposed, isTrue);
      expect(created.first.captures, 0);
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await warmUp();
      expect(created.length, 2);
      sample(0);
      sample(0);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(created.last.captures, 0);
      sample(0);
      await tester.pump(const Duration(seconds: 1));
      expect(created.last.captures, 1);
      await tester.pumpWidget(const SizedBox());
      created.last.photo.complete(XFile('unused-cancelled-photo.jpg'));
      await tester.pump();
      await events.close();
      expect(tester.takeException(), isNull);
    },
  );

  Future<_Recovery> openRecovery(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _Recovery();
    await tester.pumpWidget(
      MaterialApp(home: ForgotPasswordScreen(service: service)),
    );
    await tester.pumpAndSettle();
    return service;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'recovery validates email and does not advance on network failure',
    (tester) async {
      final service = await openRecovery(tester);
      await tester.enterText(find.byType(TextField), 'bad');
      await tapText(tester, 'SEND CODE');
      expect(service.requests, 0);
      expect(find.text('Please enter a valid email address.'), findsOneWidget);
      service.requestResult = {
        'success': false,
        'message': 'Connection timed out. Please try again.',
      };
      await tester.enterText(find.byType(TextField), 'reader@example.com');
      await tapText(tester, 'SEND CODE');
      expect(service.requests, 1);
      expect(
        find.text('Connection timed out. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('RESET PASSWORD'), findsNothing);
    },
  );

  testWidgets(
    'recovery validates code and confirmation then returns to login',
    (tester) async {
      final service = await openRecovery(tester);
      await tester.enterText(find.byType(TextField), ' reader@example.com ');
      await tapText(tester, 'SEND CODE');
      expect(
        find.textContaining('If this email is registered'),
        findsOneWidget,
      );
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      await tapText(tester, 'RESET PASSWORD');
      expect(service.resets, 0);
      expect(
        find.text('Enter the eight-digit code from your email.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField).at(0), '01234567');
      await tester.enterText(find.byType(TextField).at(1), ' exact password ');
      await tester.enterText(find.byType(TextField).at(2), 'different');
      await tapText(tester, 'RESET PASSWORD');
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(service.resets, 0);
      await tester.enterText(find.byType(TextField).at(2), ' exact password ');
      await tapText(tester, 'RESET PASSWORD');
      expect(service.submitted, [
        'reader@example.com',
        '01234567',
        ' exact password ',
      ]);
      expect(find.text('BACK TO LOGIN'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tapText(tester, 'BACK TO LOGIN');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ForgotPasswordScreen), findsNothing);
    },
  );

  testWidgets(
    'recovery retains form on invalid code and clears secrets when changing email',
    (tester) async {
      final service = await openRecovery(tester);
      await tester.enterText(find.byType(TextField), 'reader@example.com');
      await tapText(tester, 'SEND CODE');
      await tester.enterText(find.byType(TextField).at(0), '01234567');
      await tester.enterText(find.byType(TextField).at(1), 'password');
      await tester.enterText(find.byType(TextField).at(2), 'password');
      service.resetResult = {
        'success': false,
        'message': 'The code is invalid or expired.',
      };
      await tapText(tester, 'RESET PASSWORD');
      expect(service.resets, 1);
      expect(find.text('BACK TO LOGIN'), findsNothing);
      expect(find.text('The code is invalid or expired.'), findsOneWidget);
      await tapText(tester, 'USE A DIFFERENT EMAIL');
      await tapText(tester, 'SEND CODE');
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.controller!.text, isEmpty);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  Future<_LoginUser> openLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final user = _LoginUser();
    await user.ready;
    addTearDown(user.dispose);
    await tester.pumpWidget(
      UserProvider(
        notifier: user,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'reader');
    await tester.enterText(find.byType(TextField).last, 'wrong');
    return user;
  }

  testWidgets('network and ordinary auth errors never create a local lock', (
    tester,
  ) async {
    final user = await openLogin(tester);
    for (var attempt = 0; attempt < 6; attempt++) {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();
    }
    user.result = {
      'success': false,
      'status_code': 401,
      'message': 'Invalid username or password',
    };
    for (var attempt = 0; attempt < 6; attempt++) {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();
    }
    expect(user.calls, 12);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
    expect(find.textContaining('Account temporarily locked'), findsNothing);
  });

  testWidgets('server lock disables only the matching username', (
    tester,
  ) async {
    final user = await openLogin(tester);
    user.result = {
      'success': false,
      'status_code': 429,
      'retry_after_seconds': 840,
      'message': 'Too many incorrect passwords.',
    };
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Account temporarily locked'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    expect(find.textContaining('14:'), findsWidgets);
    await tester.enterText(find.byType(TextField).first, 'other');
    await tester.pump();
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
    await tester.enterText(find.byType(TextField).first, ' READER ');
    await tester.pump();
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    expect(user.calls, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('legacy ID cannot bypass login after upgrade', (tester) async {
    SharedPreferences.setMockInitialValues({
      'user_id': '1',
      'user_password': 'old-password',
    });
    final session = SessionService(store: _Store());
    await open(tester, session);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).containsKey('user_password'),
      isFalse,
    );
  });

  testWidgets(
    'restores secure session and removes protected routes on revocation',
    (tester) async {
      final now = DateTime.now().toUtc();
      final store =
          _Store()
            ..value = jsonEncode({
              'access_token': 'access',
              'refresh_token': 'refresh',
              'access_expires_at':
                  now.add(const Duration(minutes: 30)).toIso8601String(),
              'refresh_expires_at':
                  now.add(const Duration(days: 30)).toIso8601String(),
              'user_id': 1,
              'username': 'reader',
              'email': 'reader@example.com',
            });
      final session = SessionService(
        store: store,
        client: MockClient(
          (request) async => http.Response(
            '{"user_id":1,"username":"reader","email":"reader@example.com"}',
            200,
          ),
        ),
      );
      await open(tester, session);
      expect(find.byType(AssistiveReaderScreen), findsOneWidget);
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Protected details')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Protected details'), findsOneWidget);
      await session.clear();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Protected details'), findsNothing);
      expect(navigator.canPop(), isFalse);
    },
  );
}
