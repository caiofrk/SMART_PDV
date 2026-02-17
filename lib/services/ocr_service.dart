import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  static final TextRecognizer _textRecognizer = TextRecognizer();

  /// Extracts text from a given image file.
  /// Returns a cleaned-up string of the most likely product name.
  static Future<String?> extractProductName(File image) async {
    try {
      final inputImage = InputImage.fromFile(image);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      if (recognizedText.text.isEmpty) return null;

      // Extract lines and filter/clean them
      List<String> candidates = [];
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          String text = line.text.trim();
          // Filter out lines that are likely barcodes, prices, or too short
          if (_isValidNameCandidate(text)) {
            candidates.add(text);
          }
        }
      }

      if (candidates.isEmpty) return null;

      // Priority: Longest text usually contains more product info
      // but often the first/largest block is the brand name.
      // For now, let's return the most prominent one (first one detected usually)
      return candidates.first.toUpperCase();
    } catch (e) {
      print('OCR Error: $e');
      return null;
    }
  }

  static bool _isValidNameCandidate(String text) {
    // Regex to detect if text is mostly digits (barcode/price)
    final digitPattern = RegExp(r'^[0-9.,\s]+$');
    if (digitPattern.hasMatch(text)) return false;

    // Ignore terms often found in tobacco warnings/labels that aren't product names
    final blacklisted = [
      'MINISTÉRIO',
      'SAÚDE',
      'ADVERTE',
      'FUMAR',
      'CAUSA',
      'PROIBIDO',
      'VENDA',
    ];
    for (var term in blacklisted) {
      if (text.toUpperCase().contains(term)) return false;
    }

    return text.length > 2;
  }

  static void dispose() {
    _textRecognizer.close();
  }
}
