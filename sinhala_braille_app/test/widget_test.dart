import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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
