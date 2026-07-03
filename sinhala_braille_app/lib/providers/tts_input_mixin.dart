import 'package:flutter/material.dart';
import 'package:sinhala_braille_app/providers/tts_service.dart';

/// Mixin that provides real TTS speak and STT voice-dictation helpers.
///
/// Mix this into any [State] that has input fields with speaker / mic buttons.
/// Requires the widget tree to be mounted (i.e., this is a [State] mixin).
mixin TtsInputMixin<T extends StatefulWidget> on State<T> {
  bool _isListening = false;
  bool get isListening => _isListening;

  // ── Speaker (read label aloud in English) ─────────────────────────────────

  Future<void> speakLabel(String label) async {
    await TtsService.instance.speakEnglish(label);
  }

  // ── Microphone (voice dictation → fill controller) ────────────────────────

  Future<void> startVoiceDictation(TextEditingController controller) async {
    if (!TtsService.instance.sttAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech recognition is not available on this device.'),
        ),
      );
      return;
    }

    if (_isListening) {
      await TtsService.instance.stopListening();
      setState(() => _isListening = false);
      return;
    }

    setState(() => _isListening = true);

    await TtsService.instance.startListening(
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() {
          controller.text = text;
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: text.length),
          );
          if (isFinal) _isListening = false;
        });
      },
    );
  }

  /// Builds the standard microphone button used in input field rows.
  Widget buildMicButton(TextEditingController controller) {
    return GestureDetector(
      onTap: () => startVoiceDictation(controller),
      child: Container(
        width: 52,
        height: 52,
        margin: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          color: _isListening ? Colors.red : const Color(0xFF7B4FE0),
          shape: BoxShape.circle,
        ),
        child: Icon(
          _isListening ? Icons.mic_off : Icons.mic,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  /// Builds the standard speaker button used in input field rows.
  Widget buildSpeakerButton(String label) {
    return GestureDetector(
      onTap: () => speakLabel(label),
      child: Container(
        width: 52,
        height: 52,
        margin: const EdgeInsets.only(left: 10),
        decoration: const BoxDecoration(
          color: Color(0xFF7B4FE0),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.volume_up, color: Colors.white, size: 24),
      ),
    );
  }

  @override
  void dispose() {
    TtsService.instance.stopListening();
    super.dispose();
  }
}
