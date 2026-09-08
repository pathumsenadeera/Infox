import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sinhala_braille_app/providers/tts_service.dart';
import 'package:sinhala_braille_app/screen/assistive_reader_screen.dart';
import 'package:sinhala_braille_app/screen/audio_player_screen.dart';

class SavedHistoryScreen extends StatefulWidget {
  const SavedHistoryScreen({super.key});

  @override
  State<SavedHistoryScreen> createState() => _SavedHistoryScreenState();
}

class _SavedHistoryScreenState extends State<SavedHistoryScreen> {
  // Mock local document store with IDs (FR 26 & FR 27)
  final List<Map<String, String>> _documents = [
    {
      'id': 'doc_001',
      'title': 'Math Notes – Chapter 3',
      'date': '2026-03-05',
      'text': 'ගණිතය – පරිච්ඡේදය 3\n\nසංඛ්‍යා රටා සහ ක්‍රම...',
    },
    {
      'id': 'doc_002',
      'title': 'Science Chapter 2',
      'date': '2026-03-04',
      'text': 'විද්‍යාව – ජීව රසායනය\n\nකොෂ ව්‍යුහය සහ ක්‍රියාකාරිත්වය...',
    },
    {
      'id': 'doc_003',
      'title': 'Sinhala Notes',
      'date': '2026-03-01',
      'text': 'සිංහල – ව්‍යාකරණය\n\nඅකුරු හා ව්‍යාකරණ නීති...',
    },
    {
      'id': 'doc_004',
      'title': 'History – Ancient Lanka',
      'date': '2026-02-28',
      'text': 'ඉතිහාසය – පුරාණ ලංකාව\n\nඅනුරාධපුර රාජධානිය...',
    },
  ];

  // Single tap on document card → open saved document (FR 26)
  void _onSingleTap(Map<String, String> doc) {
    _openDoc(doc);
  }

  // Double tap on document card → open saved document or resume reading (FR 26)
  void _onDoubleTap(Map<String, String> doc) {
    _openDoc(doc);
  }

  void _openDoc(Map<String, String> doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AudioPlayerScreen(
              documentId: doc['id'],
              translatedText: doc['text'],
              documentTitle: doc['title'],
            ),
      ),
    );
  }

  // Swipe left → delete saved document (FR 26)
  void _onDeleteDoc(int index) {
    final deleted = _documents.removeAt(index);
    setState(() {});
    TtsService.instance.speakEnglish('Document deleted');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${deleted['title']}" deleted'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      'SAVED\nHISTORY',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Document list with swipe-to-delete
            Expanded(
              child:
                  _documents.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No saved documents yet.',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 4,
                        ),
                        itemCount: _documents.length,
                        itemBuilder: (context, index) {
                          final doc = _documents[index];
                          return Dismissible(
                            key: Key('${doc['title']}_$index'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              margin: const EdgeInsets.only(bottom: 18),
                              decoration: BoxDecoration(
                                color: Colors.red[600],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Delete',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            onDismissed: (_) => _onDeleteDoc(index),
                            child: GestureDetector(
                              onTap: () => _onSingleTap(doc),
                              onDoubleTap: () => _onDoubleTap(doc),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 18),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7B4FE0),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Document',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white70,
                                            ),
                                          ),
                                          Text(
                                            doc['title']!,
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Saved: ${doc['date']!}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _onDoubleTap(doc),
                                      child: Container(
                                        width: 56,
                                        height: 56,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFD9D9D9),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow,
                                          color: Color(0xFF7B4FE0),
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            ),

            // Bottom instruction bar
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF7B4FE0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Single tap  →  Hear Title',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Double tap  →  Open Document',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Swipe Left  →  Delete Document',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      TtsService.instance.speakEnglish(
                        'Single tap to hear title. Double tap to open document. Swipe left to delete.',
                      );
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD9D9D9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.volume_up,
                        color: Color(0xFF7B4FE0),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
