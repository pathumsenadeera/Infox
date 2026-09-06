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
