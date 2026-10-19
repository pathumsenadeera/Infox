import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SavedTranslation {
  final String id, title, text;
  final DateTime savedAt;
  const SavedTranslation({
    required this.id,
    required this.title,
    required this.text,
    required this.savedAt,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'text': text,
    'saved_at': savedAt.toIso8601String(),
  };
  factory SavedTranslation.fromJson(Map<String, dynamic> data) =>
      SavedTranslation(
        id: data['id'] as String,
        title: data['title'] as String,
        text: data['text'] as String,
        savedAt: DateTime.parse(data['saved_at'] as String),
      );
}

/// App-private files, scoped by account. Each scan has one replaceable local copy.
class SavedTranslationService {
  SavedTranslationService({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;
  static final instance = SavedTranslationService();
  final Future<Directory> Function() _directory;
  Future<void> _writes = Future.value();

  Future<Directory> _folder(String userId) async {
    if (!RegExp(r'^\d+$').hasMatch(userId)) {
      throw ArgumentError('Invalid account');
    }
    final root = await _directory();
    return Directory('${root.path}/translations/$userId');
  }

  Future<List<SavedTranslation>> list(String userId) async {
    await _writes;
    final folder = await _folder(userId);
    if (!await folder.exists()) return [];
    final result = <SavedTranslation>[];
    await for (final entry in folder.list()) {
      if (entry is File && entry.path.endsWith('.json')) {
        result.add(
          SavedTranslation.fromJson(
            jsonDecode(await entry.readAsString()) as Map<String, dynamic>,
          ),
        );
      }
    }
    result.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return result;
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final next = _writes.then((_) => operation());
    _writes = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  String _filename(String id) => '${base64Url.encode(utf8.encode(id))}.json';
  Future<void> save(String userId, SavedTranslation item) =>
      _serialize(() async {
        if (item.title.trim().isEmpty || item.text.trim().isEmpty) {
          throw ArgumentError('A title and translation are required.');
        }
        final folder = await _folder(userId);
        await folder.create(recursive: true);
        final target = '${folder.path}/${_filename(item.id)}';
        final temporary = File('$target.tmp');
        await temporary.writeAsString(jsonEncode(item.toJson()), flush: true);
        await temporary.rename(target);
      });

  Future<void> delete(String userId, String id) => _serialize(() async {
    final folder = await _folder(userId);
    final file = File('${folder.path}/${_filename(id)}');
    if (await file.exists()) await file.delete();
  });
}
