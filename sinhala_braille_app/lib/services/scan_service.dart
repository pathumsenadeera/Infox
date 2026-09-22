import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Service responsible for uploading captured Braille images to the backend
/// server and receiving the translated Sinhala text in response.
///
/// Backend pipeline:
///   1. Receive full-page JPEG
///   2. Run YOLOv8 page-detect model -> crop to braille page
///   3. Run dot-segmentation model -> extract braille dots
///   4. Translate -> return Sinhala Unicode text
class ScanService {
  static const String _baseUrl = 'https://server.projectinfox.tech';

  /// Uploads a full-resolution Braille page image for backend processing.
  /// Returns a [ScanResult] on success, throws on network or server error.
  static Future<ScanResult> uploadBrailleImage({
    required File imageFile,
    required int userId,
    void Function(String)? onStatusUpdate,
  }) async {
    final uri = Uri.parse('$_baseUrl/scan');

    final request = http.MultipartRequest('POST', uri)
      ..fields['user_id'] = userId.toString()
      ..files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

    // 60 s initial timeout — gives the server time to accept the upload
    final streamedResponse = await request
        .send()
        .timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamedResponse);

    // Accept both 200 OK and 201 Created — FastAPI returns 201 for a new scan.
    if (response.statusCode == 200 || response.statusCode == 201) {
      final dynamic data = json.decode(response.body);
      if (data is Map<String, dynamic> && data.containsKey('scan_id')) {
        final int scanId = data['scan_id'];
        return _pollScanStatus(scanId, onStatusUpdate);
      }
      throw Exception('Unexpected server response format');
    } else {
      // Extract the detail message if the body is valid JSON, otherwise use a
      // generic message. Avoids the previous string-match rethrow anti-pattern
      // that could silently swallow real exceptions.
      String errorMessage = 'Server error ${response.statusCode}';
      try {
        final errorBody = json.decode(response.body) as Map<String, dynamic>;
        errorMessage = errorBody['detail'] as String? ?? errorMessage;
      } catch (_) {
        // Body was not valid JSON — keep the generic message.
      }
      throw Exception(errorMessage);
    }
  }

  /// Polls the server until the scan is complete.
  /// Gives up after [_maxPolls] attempts (~2 minutes) to prevent an infinite hang
  /// when the server gets stuck in 'pending'.
  static const int _maxPolls = 40; // 40 × 3 s = 120 s max wait

  static Future<ScanResult> _pollScanStatus(int scanId, void Function(String)? onStatusUpdate) async {
    final uri = Uri.parse('$_baseUrl/scan/$scanId');
    int polls = 0;

    // Poll every 3 seconds up to _maxPolls times
    while (polls < _maxPolls) {
      if (onStatusUpdate != null) onStatusUpdate('pending');
      await Future.delayed(const Duration(seconds: 3));
      polls++;

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final status = data['status'];

        if (onStatusUpdate != null) onStatusUpdate(status);

        if (status == 'done') {
          return ScanResult.fromJson(data);
        } else if (status == 'error') {
          throw Exception(data['error_message'] ?? 'Translation failed on server.');
        }
        // If status == 'pending', continue polling
      } else {
        throw Exception('Server returned status ${response.statusCode} while polling');
      }
    }

    throw Exception('Translation timed out after ${_maxPolls * 3} seconds. Please try again.');
  }
}

/// Data class representing the result of a Braille scan + translation.
class ScanResult {
  final String translatedText;
  final double confidence;
  final int? docId;

  const ScanResult({
    required this.translatedText,
    required this.confidence,
    this.docId,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      translatedText: json['translated_text'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      docId: json['doc_id'] as int?,
    );
  }
}