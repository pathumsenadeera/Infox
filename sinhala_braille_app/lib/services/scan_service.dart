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
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

    // Initial request timeout can be shorter since processing is async
    final streamedResponse = await request
        .send()
        .timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final dynamic data = json.decode(response.body);
      if (data is Map<String, dynamic> && data.containsKey('scan_id')) {
        final int scanId = data['scan_id'];
        return _pollScanStatus(scanId, onStatusUpdate);
      }
      throw Exception('Unexpected server response format');
    } else {
      try {
        final errorBody = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorBody['detail'] ?? 'Server error ${response.statusCode}');
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatException')) {
          rethrow;
        }
        throw Exception('Server returned status ${response.statusCode}');
      }
    }
  }

  /// Polls the server until the scan is complete.
  static Future<ScanResult> _pollScanStatus(int scanId, void Function(String)? onStatusUpdate) async {
    final uri = Uri.parse('$_baseUrl/scan/$scanId');
    
    // Poll every 3 seconds
    while (true) {
      if (onStatusUpdate != null) onStatusUpdate('pending');
      await Future.delayed(const Duration(seconds: 3));
      
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