import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinhala_braille_app/services/saved_translation_service.dart';
import 'package:sinhala_braille_app/services/session_service.dart';
import 'package:sinhala_braille_app/providers/app_settings_provider.dart';
import 'package:sinhala_braille_app/providers/tts_service.dart';
import 'package:sinhala_braille_app/screen/assistive_reader_screen.dart';

class AudioPlayerScreen extends StatefulWidget {
  /// Optional translated text passed from the scan result.
  /// Empty when no translation is available.
  final String? translatedText;
  final String? documentTitle;
  final String? documentId;

  const AudioPlayerScreen({
    super.key,
    this.translatedText,
    this.documentTitle,
    this.documentId,
  });

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen>
    with WidgetsBindingObserver {
  bool _isPlaying = false;
  int _playbackGeneration = 0;
  late final Future<void> _bookmarkReady;

  final String? _owner = SessionService.instance.userId;
  late final String _identifier =
      widget.documentId ?? 'local_${DateTime.now().microsecondsSinceEpoch}';
  String get _displayText => widget.translatedText ?? '';
  String get _title => widget.documentTitle ?? 'Scan Result';
  // ── Paragraph / sentence tracking for rewind/forward + bookmark ──────────
  late List<String> _paragraphs;
  int _currentIndex = 0;

  String _bookmarkKey(String id) => 'bookmark_${_owner}_$id';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Split on blank lines (paragraphs) then fall back to sentences
    _paragraphs = _splitIntoParagraphs(_displayText);
    _bookmarkReady = _loadBookmark();

    // Verify language pack availability upon loading audio player (FR 24)
    TtsService.instance.verifySinhalaVoicePack();

    // Track word/character progress (FR 25)
    TtsService.instance.onProgress = (text, start, end, word) {
      if (mounted) {
        debugPrint('Reading word: $word ($start-$end)');
      }
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Save reading position when app goes into background or pauses (FR 27)
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveBookmark();
      ++_playbackGeneration;
      TtsService.instance.stop();
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  List<String> _splitIntoParagraphs(String text) {
    // Split by double newlines first
    final parts =
        text
            .split(RegExp(r'\n\s*\n'))
            .where((s) => s.trim().isNotEmpty)
            .toList();
    if (parts.length > 1) return parts;
    // Fall back to sentence splitting
    return text
        .split(RegExp(r'(?<=[.!?।])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }

  Future<void> _loadBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_bookmarkKey(_identifier)) ?? 0;
    if (mounted && saved > 0 && saved < _paragraphs.length) {
      setState(() => _currentIndex = saved);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resuming from bookmark (section ${saved + 1})'),
            backgroundColor: const Color(0xFF7B4FE0),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _saveBookmark() async {
    if (_owner == null || _displayText.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bookmarkKey(_identifier), _currentIndex);
  }

  // ── Playback controls ─────────────────────────────────────────────────────

  Future<void> _togglePlay() async {
    if (_paragraphs.isEmpty) return;
    if (_isPlaying) {
      ++_playbackGeneration;
      setState(() => _isPlaying = false);
      await TtsService.instance.stop();
    } else {
      await _startPlayback();
    }
  }

  Future<void> _startPlayback({int? section}) async {
    final generation = ++_playbackGeneration;
    await _bookmarkReady;
    if (!mounted || generation != _playbackGeneration) return;
    await TtsService.instance.stop();
    if (!mounted || generation != _playbackGeneration) return;
    setState(() {
      if (section != null) _currentIndex = section;
      _isPlaying = true;
    });
    try {
      for (int i = _currentIndex; i < _paragraphs.length; i++) {
        if (!mounted || generation != _playbackGeneration) return;
        setState(() => _currentIndex = i);
        await _saveBookmark();
        if (!mounted || generation != _playbackGeneration) return;
        final settings = AppSettings.of(context);
        final completed = await TtsService.instance.speakSinhala(
          _paragraphs[i],
          speechRate: settings.speechRate,
          voiceType: settings.voiceType,
        );
        if (!mounted || generation != _playbackGeneration) return;
        if (!completed) {
          setState(() => _isPlaying = false);
          return;
        }
      }
      if (mounted && generation == _playbackGeneration) {
        setState(() {
          _isPlaying = false;
          _currentIndex = 0;
        });
        await _saveBookmark();
      }
    } catch (_) {
      if (mounted && generation == _playbackGeneration) {
        setState(() => _isPlaying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech playback failed. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _onRewind() async {
    if (_paragraphs.isEmpty) return;
    await _startPlayback(
      section: (_currentIndex - 1).clamp(0, _paragraphs.length - 1),
    );
  }

  Future<void> _onForward() async {
    if (_paragraphs.isEmpty) return;
    await _startPlayback(
      section: (_currentIndex + 1).clamp(0, _paragraphs.length - 1),
    );
  }
  // ── Save document dialog ──────────────────────────────────────────────────

  Future<void> _onDownload() async {
    if (_owner == null || _displayText.trim().isEmpty) return;
    final controller = TextEditingController(text: _title);
    bool saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, update) => PopScope(
                  canPop: !saving,
                  child: AlertDialog(
                    title: const Text('Save on this device'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Available offline in Saved locally. Saving again updates this scan’s local copy.',
                        ),
                        TextField(
                          controller: controller,
                          enabled: !saving,
                          maxLength: 120,
                          decoration: InputDecoration(
                            labelText: 'Document name',
                            errorText: error,
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: saving ? null : () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed:
                            saving
                                ? null
                                : () async {
                                  final title = controller.text.trim();
                                  if (title.isEmpty) {
                                    update(
                                      () => error = 'Please enter a name.',
                                    );
                                    return;
                                  }
                                  update(() {
                                    saving = true;
                                    error = null;
                                  });
                                  try {
                                    if (SessionService.instance.userId !=
                                        _owner) {
                                      throw const SessionExpired();
                                    }
                                    await SavedTranslationService.instance.save(
                                      _owner,
                                      SavedTranslation(
                                        id: _identifier,
                                        title: title,
                                        text: _displayText,
                                        savedAt: DateTime.now(),
                                      ),
                                    );
                                    if (!ctx.mounted) return;
                                    Navigator.pop(ctx);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Translation saved on this device.',
                                        ),
                                      ),
                                    );
                                    TtsService.instance.speakEnglish(
                                      'Translation saved on this device',
                                    );
                                  } on DuplicateTranslationName {
                                    if (ctx.mounted) {
                                      update(() {
                                        saving = false;
                                        error =
                                            DuplicateTranslationName.message;
                                      });
                                      TtsService.instance.announceError(
                                        DuplicateTranslationName.message,
                                      );
                                    }
                                  } catch (_) {
                                    if (ctx.mounted) {
                                      update(() {
                                        saving = false;
                                        error = 'Could not save. Please retry.';
                                      });
                                    }
                                  }
                                },
                        child: Text(saving ? 'Saving…' : 'Save'),
                      ),
                    ],
                  ),
                ),
          ),
    );
    // The dialog route may still be animating out; dispose after its transition.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
  }

  @override
  void dispose() {
    ++_playbackGeneration;
    WidgetsBinding.instance.removeObserver(this);
    _saveBookmark();
    TtsService.instance.stop();
    TtsService.instance.onProgress = null;
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final double progress =
        _paragraphs.isEmpty ? 0 : (_currentIndex + 1) / _paragraphs.length;

    // Double-tap anywhere on the screen toggles play/pause (SDS requirement)
    return GestureDetector(
      onDoubleTap: _togglePlay,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Purple header
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF7B4FE0),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        TtsService.instance.stop();
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                          return;
                        }
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AssistiveReaderScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_back_sharp, size: 30),
                      style: ButtonStyle(
                        backgroundColor: WidgetStatePropertyAll(
                          Colors.grey.shade300,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'AUDIO\nPLAYER & RESULT',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                    // Save / download button
                    GestureDetector(
                      onTap: _onDownload,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.file_download_outlined,
                          color: Color(0xFF7B4FE0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Double-tap hint
              Text(
                'Double-tap anywhere to Play / Pause',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.black38),
              ),

              const SizedBox(height: 4),

              // Reading progress bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF7B4FE0),
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Section ${_currentIndex + 1} of ${_paragraphs.length}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.black38,
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            ++_playbackGeneration;
                            await _bookmarkReady;
                            if (!context.mounted) return;
                            final messenger = ScaffoldMessenger.of(context);
                            setState(() {
                              _currentIndex = 0;
                              _isPlaying = false;
                            });
                            await TtsService.instance.stop();
                            await _saveBookmark();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Bookmark cleared'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Text(
                            'Reset bookmark',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF7B4FE0),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Translated text result box
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F0FB),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF7B4FE0).withValues(alpha: 0.3),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _displayText,
                        textAlign: TextAlign.left,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          color: Colors.black87,
                          height: 1.7,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Playback controls row: Rewind — Play/Pause — Forward
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Rewind
                    GestureDetector(
                      onTap: _onRewind,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: const BoxDecoration(
                          color: Color(0xFF7B4FE0),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fast_rewind,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),

                    // Play / Pause (large, central)
                    GestureDetector(
                      onTap: _togglePlay,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: const BoxDecoration(
                          color: Color(0xFF7B4FE0),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                    ),

                    // Forward
                    GestureDetector(
                      onTap: _onForward,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: const BoxDecoration(
                          color: Color(0xFF7B4FE0),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fast_forward,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
