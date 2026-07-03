// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:sinhala_braille_app/main.dart';
import 'package:sinhala_braille_app/providers/app_settings_provider.dart';
import 'package:sinhala_braille_app/providers/user_provider.dart';

void main() {
  testWidgets('Welcome screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      AppSettings(
        notifier: AppSettingsNotifier(),
        child: UserProvider(
          notifier: UserNotifier(),
          child: const MyApp(),
        ),
      ),
    );

    // Verify that GET STARTED button is present.
    expect(find.text('GET STARTED'), findsOneWidget);
  });
}
