import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinhala_braille_app/services/saved_translation_service.dart';
import 'package:sinhala_braille_app/services/scan_service.dart';

void main() {
  test(
    'cancellation before upload never reads a file or contacts the server',
    () async {
      await expectLater(
        ScanService.uploadBrailleImage(
          imageFile: File('does-not-exist.jpg'),
          userId: 1,
          isCancelled: () => true,
        ),
        throwsException,
      );
    },
  );
  late Directory root;
  late SavedTranslationService store;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('infox_saved_test_');
    store = SavedTranslationService(directory: () async => root);
  });
  tearDown(() async => root.delete(recursive: true));
  SavedTranslation item(String title, {String id = 'scan_12'}) =>
      SavedTranslation(
        id: id,
        title: title,
        text: 'සිංහල\n\nTranslation',
        savedAt: DateTime.utc(2026, 10, 19),
      );

  test(
    'persists Unicode text across service instances and isolates accounts',
    () async {
      await store.save('1', item('Notes'));
      final reopened = SavedTranslationService(directory: () async => root);
      expect((await reopened.list('1')).single.text, 'සිංහල\n\nTranslation');
      expect(await reopened.list('2'), isEmpty);
    },
  );
  test(
    'repeated saves replace one copy and deletion affects only its owner',
    () async {
      await store.save('1', item('First'));
      await store.save('2', item('Other account'));
      await store.save('1', item('Renamed'));
      expect((await store.list('1')).single.title, 'Renamed');
      await store.delete('1', 'scan_12');
      expect(await store.list('1'), isEmpty);
      expect((await store.list('2')).single.title, 'Other account');
    },
  );
  test(
    'concurrent saves retain distinct documents and reject invalid data',
    () async {
      await Future.wait([
        store.save('1', item('A')),
        store.save('1', item('B', id: 'scan_13')),
      ]);
      expect(await store.list('1'), hasLength(2));
      await expectLater(
        store.save('../escape', item('Invalid')),
        throwsArgumentError,
      );
      await expectLater(store.save('1', item(' ')), throwsArgumentError);
      expect(await store.list('1'), hasLength(2));
    },
  );
  test(
    'corrupt storage produces an error instead of claiming no saved data',
    () async {
      await store.save('1', item('A'));
      final file =
          await Directory('${root.path}/translations/1').list().first as File;
      await file.writeAsString('broken');
      await expectLater(store.list('1'), throwsFormatException);
    },
  );
  test('scan response uses server scan id for stable local identity', () {
    expect(
      ScanResult.fromJson({'scan_id': 42, 'translated_text': 'text'}).docId,
      42,
    );
  });

  test(
    'duplicate names ignore case and whitespace but allow same scan and other accounts',
    () async {
      await store.save('1', item('My Notes'));
      await expectLater(
        store.save('1', item('  my   NOTES ', id: 'scan_13')),
        throwsA(isA<DuplicateTranslationName>()),
      );
      expect((await store.list('1')).single.title, 'My Notes');
      await store.save('1', item('MY NOTES'));
      await store.save('2', item('my notes', id: 'scan_13'));
      expect(await store.list('1'), hasLength(1));
      expect(await store.list('2'), hasLength(1));
    },
  );

  test(
    'rename conflict preserves both copies and deletion frees the name',
    () async {
      await store.save('1', item('සිංහල'));
      await store.save('1', item('Other', id: 'scan_13'));
      await expectLater(
        store.save('1', item('සිංහල', id: 'scan_13')),
        throwsA(isA<DuplicateTranslationName>()),
      );
      expect((await store.list('1')).map((entry) => entry.title).toSet(), {
        'සිංහල',
        'Other',
      });
      await store.delete('1', 'scan_12');
      await store.save('1', item('සිංහල', id: 'scan_13'));
      expect((await store.list('1')).single.id, 'scan_13');
    },
  );

  test(
    'simultaneous duplicate saves produce one copy and one conflict',
    () async {
      final first = store.save('1', item('Shared'));
      final second = store.save('1', item('shared', id: 'scan_13'));
      await Future.wait([
        first,
        expectLater(second, throwsA(isA<DuplicateTranslationName>())),
      ]);
      expect(await store.list('1'), hasLength(1));
    },
  );
}
