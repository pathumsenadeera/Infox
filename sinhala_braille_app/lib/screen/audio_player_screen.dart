import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sinhala_braille_app/screen/assistive_reader_screen.dart';

class AudioPlayerScreen extends StatefulWidget {
  /// Optional translated text passed from the scan result.
  /// Falls back to sample Sinhala Unicode text if not provided.
  final String? translatedText;
  final String? documentTitle;

  const AudioPlayerScreen({
    super.key,
    this.translatedText,
    this.documentTitle,
  });

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
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

  // ── Playback controls ────────────────────────────────────────────────────

  void _togglePlay() {
    setState(() => _isPlaying = !_isPlaying);
    // TTS engine call will be wired here in Phase 2
  }

  void _onRewind() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rewinding...')),
    );
  }

  void _onForward() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Forwarding...')),
    );
  }

  // ── Save document dialog ─────────────────────────────────────────────────

  void _onDownload() {
    final titleController = TextEditingController(text: _title);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54),
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
                  const SnackBar(content: Text('Please enter a document name.')),
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

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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

              const SizedBox(height: 16),

              // Double-tap hint
              Text(
                'Double-tap anywhere to Play / Pause',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black38,
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
