import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sinhala_braille_app/providers/tts_service.dart';
import 'package:sinhala_braille_app/services/session_service.dart';
import 'package:sinhala_braille_app/services/saved_translation_service.dart';
import 'package:sinhala_braille_app/screen/audio_player_screen.dart';
import 'package:sinhala_braille_app/screen/assistive_reader_screen.dart';

class SavedHistoryScreen extends StatefulWidget {
  const SavedHistoryScreen({super.key});
  @override
  State<SavedHistoryScreen> createState() => _SavedHistoryScreenState();
}

class _SavedHistoryScreenState extends State<SavedHistoryScreen> {
  final _owner = SessionService.instance.userId;
  List<SavedTranslation> _saved = [];
  final List<Map<String, dynamic>> _scans = [];
  int? _next;
  bool _local = true, _loading = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_owner == null || SessionService.instance.userId != _owner) {
        throw const SessionExpired();
      }
      if (_local) {
        final saved = await SavedTranslationService.instance.list(_owner);
        if (!mounted || generation != _generation) return;
        _saved = saved;
      } else {
        final response = await SessionService.instance.request(
          'GET',
          '/scans?limit=20${more && _next != null ? '&before=$_next' : ''}',
        );
        if (response.statusCode != 200) {
          throw Exception('Unable to load past scans.');
        }
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (!mounted || generation != _generation) return;
        if (!more) _scans.clear();
        _scans.addAll((data['scans'] as List).cast<Map<String, dynamic>>());
        _next = data['next_before'] as int?;
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        _error =
            _local
                ? 'Could not read saved translations. Please retry.'
                : 'Could not load past scans. Check your connection and retry.';
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _open(String id, String title, String text) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AudioPlayerScreen(
              documentId: id,
              documentTitle: title,
              translatedText: text,
            ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _delete(SavedTranslation item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete local copy?'),
            content: Text(
              'Remove "${item.title}" from this device? Your server scan will remain.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await SavedTranslationService.instance.delete(_owner!, item.id);
      if (!mounted) return;
      setState(() => _saved.removeWhere((entry) => entry.id == item.id));
      TtsService.instance.speakEnglish('Local copy deleted');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete local copy. Please retry.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back to dashboard',
        icon: const Icon(Icons.arrow_back),
        onPressed:
            () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AssistiveReaderScreen()),
            ),
      ),
      title: const Text('Saved & history'),
      backgroundColor: const Color(0xFF7B4FE0),
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _loading ? null : () => _load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Saved locally')),
              ButtonSegment(value: false, label: Text('Past scans')),
            ],
            selected: {_local},
            onSelectionChanged: (selection) {
              setState(() => _local = selection.first);
              _load();
            },
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(_error!),
                TextButton(
                  onPressed: () => _load(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        Expanded(child: _local ? _localList() : _historyList()),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _local
                ? 'Tap to hear title. Double tap or press play to open. Swipe left to delete local copy.'
                : 'Past scans are stored on the server. Open a completed scan to save it for offline reading.',
          ),
        ),
      ],
    ),
  );

  Widget _localList() {
    if (_saved.isEmpty) {
      return const Center(child: Text('No saved translations yet.'));
    }
    return ListView(
      children:
          _saved
              .map(
                (item) => Dismissible(
                  key: ValueKey(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Icon(Icons.delete, color: Colors.white),
                    ),
                  ),
                  confirmDismiss: (_) async {
                    await _delete(item);
                    return false;
                  },
                  child: _tile(
                    item.id,
                    item.title,
                    item.text,
                    'Saved ${item.savedAt.toLocal().toString().split('.').first}',
                    delete: () => _delete(item),
                  ),
                ),
              )
              .toList(),
    );
  }

  Widget _historyList() {
    if (_scans.isEmpty) return const Center(child: Text('No past scans yet.'));
    return ListView(
      children: [
        for (final scan in _scans)
          _tile(
            'scan_${scan['scan_id']}',
            'Scan ${scan['scan_id']}',
            scan['translated_text'] as String? ?? '',
            '${scan['created_at']} • ${scan['status']}',
            enabled:
                scan['status'] == 'done' &&
                (scan['translated_text'] as String? ?? '').trim().isNotEmpty,
          ),
        if (_next != null)
          TextButton(
            onPressed: _loading ? null : () => _load(more: true),
            child: const Text('Load more'),
          ),
      ],
    );
  }

  Widget _tile(
    String id,
    String title,
    String text,
    String subtitle, {
    VoidCallback? delete,
    bool enabled = true,
  }) => GestureDetector(
    onDoubleTap: enabled ? () => _open(id, title, text) : null,
    child: ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () => TtsService.instance.speakEnglish(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Open translation',
            onPressed: enabled ? () => _open(id, title, text) : null,
            icon: const Icon(Icons.play_arrow),
          ),
          if (delete != null)
            IconButton(
              tooltip: 'Delete local copy',
              onPressed: delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    ),
  );
}
