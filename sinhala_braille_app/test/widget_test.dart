import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sinhala_braille_app/main.dart';

void main() {
  testWidgets('shows the welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('GET START'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
