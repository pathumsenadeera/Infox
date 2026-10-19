import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinhala_braille_app/providers/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Android document playback maps account multipliers to native speed',
    () async {
      final rates = <double>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
            call,
          ) async {
            if (call.method == 'setSpeechRate') {
              rates.add(call.arguments as double);
            }
            if (call.method == 'getLanguages') return ['si-LK'];
            return 1;
          });
      for (final rate in [0.5, 1.0, 1.5, 2.0, 3.0]) {
        await TtsService.instance.speakSinhala('Translation', speechRate: rate);
      }
      expect(rates, [0.25, 0.5, 0.75, 1.0, 1.5]);
      await TtsService.instance.speakSinhala('Replay');
      expect(rates.last, 0.5);
    },
  );
}
