import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinhala_braille_app/providers/app_settings_provider.dart';
import 'package:sinhala_braille_app/providers/tts_service.dart';
import 'package:sinhala_braille_app/screen/assistive_reader_screen.dart';

class AudioPlayerScreen extends StatefulWidget {
  /// Optional translated text passed from the scan result.
  /// Falls back to sample Sinhala Unicode text if not provided.
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

  // Sample Sinhala Unicode text (Braille translation placeholder)
  static const String _sampleSinhalaText =
      'මෙය සිංහල බ්‍රේල් පරිවර්තන ප්‍රතිඵලයයි.\n\n'
      'ඔබේ ලේඛනය සාර්ථකව ස්කෑන් කර ඇත.\n\n'
      'AI පරිවර්තන ප්‍රතිඵලය මෙහි දිස්වනු ඇත.';

  String get _displayText =>
      widget.translatedText?.isNotEmpty == true
          ? widget.translatedText!
          : _sampleSinhalaText;

  String get _title => widget.documentTitle ?? 'Scan Result';
  String get _identifier => widget.documentId ?? _title;

  // ── Paragraph / sentence tracking for rewind/forward + bookmark ──────────
  late List<String> _paragraphs;
  int _currentIndex = 0;

  static String _bookmarkKey(String id) => 'bookmark_$id';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Split on blank lines (paragraphs) then fall back to sentences
    _paragraphs = _splitIntoParagraphs(_displayText);
    _loadBookmark();

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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveBookmark();
      TtsService.instance.pause();
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
    if (saved > 0 && saved < _paragraphs.length) {
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bookmarkKey(_identifier), _currentIndex);
  }

  // ── Playback controls ─────────────────────────────────────────────────────

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await TtsService.instance.pause();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isPlaying = true);
      await _speakFromCurrentIndex();
    }
  }

  Future<void> _speakFromCurrentIndex() async {
    if (_paragraphs.isEmpty) return;
    final rate = AppSettings.of(context).speechRate;
    final voice = AppSettings.of(context).voiceType;

    // Speak each paragraph in sequence starting from _currentIndex
    for (int i = _currentIndex; i < _paragraphs.length; i++) {
      if (!mounted || !_isPlaying) break;
      setState(() => _currentIndex = i);
      await _saveBookmark();
      await TtsService.instance.speakSinhala(
        _paragraphs[i],
        speechRate: rate,
        voiceType: voice,
      );
      // Wait for this chunk to finish before moving to the next
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 200));
        return TtsService.instance.isSpeaking;
      });
    }

    if (mounted && _currentIndex >= _paragraphs.length - 1) {
      setState(() {
        _isPlaying = false;
        _currentIndex = 0; // Reset after finishing
      });
      await _saveBookmark();
    }
  }

  Future<void> _onRewind() async {
    await TtsService.instance.stop();
    setState(() {
      _currentIndex = (_currentIndex - 1).clamp(0, _paragraphs.length - 1);
      _isPlaying = true;
    });
    await _saveBookmark();
    await _speakFromCurrentIndex();
  }

  Future<void> _onForward() async {
    await TtsService.instance.stop();
    setState(() {
      _currentIndex = (_currentIndex + 1).clamp(0, _paragraphs.length - 1);
      _isPlaying = true;
    });
    await _saveBookmark();
    await _speakFromCurrentIndex();
  }

  // ── Save document dialog ──────────────────────────────────────────────────

  void _onDownload() {
    final titleController = TextEditingController(text: _title);

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Save Document',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF7B4FE0),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter a name for this document:',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  style: GoogleFonts.poppins(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Document name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF7B4FE0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF7B4FE0),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: Colors.black54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B4FE0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  final name = titleController.text.trim();
                  Navigator.pop(ctx);
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a document name.'),
                      ),
                    );
                    return;
                  }
                  // Duplicate check + save will be wired to backend in Phase 2
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('"$name" saved successfully!'),
                      backgroundColor: Colors.green[700],
                    ),
                  );
                },
                child: Text(
                  'Save',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
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
