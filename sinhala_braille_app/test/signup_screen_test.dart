import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// Font loading is replaced so form tests need neither network nor font files.
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as fonts;
import 'package:sinhala_braille_app/screen/signup_screen.dart';

class _FontManifest implements AssetManifest {
  @override
  List<String> listAssets() => [
    for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold'])
      'Poppins-$weight.ttf',
  ];

  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final spoken = <String>[];

  setUp(() {
    spoken.clear();
    fonts.assetManifest = _FontManifest();
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
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
      call,
    ) async {
      if (call.method == 'speak') {
        spoken.add(call.arguments as String);
      }
      return 1;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugin.csdcorp.com/speech_to_text'),
      (_) async => true,
    );
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Sign Up'));
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'announces strength after a pause and only when category changes',
    (tester) async {
      await open(tester);
      final password = find.byType(TextField).at(2);
      await tester.enterText(password, 'a');
      await tester.pump(const Duration(milliseconds: 300));
      expect(spoken, isEmpty);
      await tester.enterText(password, 'ab');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(spoken, ['Password strength: Weak']);
      await tester.enterText(password, 'abc');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(spoken, ['Password strength: Weak']);
      await tester.enterText(password, 'Abcd123!');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(spoken.last, 'Password strength: Strong');
    },
  );

  testWidgets('focuses and announces each first empty field in form order', (
    tester,
  ) async {
    await open(tester);
    final values = [
      'reader',
      'reader+notes@example.technology',
      'Abcd123!',
      '',
    ];
    final labels = ['username', 'email', 'password', 'confirm password'];
    for (var i = 0; i < 4; i++) {
      await submit(tester);
      expect(
        tester
            .widget<TextField>(find.byType(TextField).at(i))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      expect(spoken, contains('Please enter your ${labels[i]}.'));
      if (i < 3) {
        await tester.enterText(find.byType(TextField).at(i), values[i]);
      }
    }
  });

  testWidgets('invalid email then mismatch focus the relevant field', (
    tester,
  ) async {
    await open(tester);
    final values = ['reader', 'bad@email', 'Abcd123!', 'different'];
    for (var i = 0; i < 4; i++) {
      await tester.enterText(find.byType(TextField).at(i), values[i]);
    }
    await submit(tester);
    expect(
      tester
          .widget<TextField>(find.byType(TextField).at(1))
          .focusNode!
          .hasFocus,
      isTrue,
    );
    await tester.enterText(
      find.byType(TextField).at(1),
      'reader+notes@example.technology',
    );
    await submit(tester);
    expect(
      tester
          .widget<TextField>(find.byType(TextField).at(3))
          .focusNode!
          .hasFocus,
      isTrue,
    );
    expect(spoken, contains('Passwords do not match.'));
  });
}
