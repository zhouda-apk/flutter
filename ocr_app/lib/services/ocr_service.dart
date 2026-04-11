import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.chinese,
  );

  // ── 辨識單張圖片 ─────────────────────────────────────────
  Future<OcrResult> recognizeText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);

    try {
      final recognized = await _recognizer.processImage(inputImage);

      final blocks = recognized.blocks.map((block) {
        return OcrBlock(
          text: block.text,
          confidence: block.lines
              .expand((l) => l.elements)
              .map((e) => e.confidence ?? 0.0)
              .fold(0.0, (a, b) => a + b) /
              (block.lines.expand((l) => l.elements).length.clamp(1, 999)),
        );
      }).toList();

      final fullText = recognized.text;
      final avgConfidence = blocks.isEmpty
          ? 0.0
          : blocks.map((b) => b.confidence).reduce((a, b) => a + b) /
              blocks.length;

      return OcrResult(
        fullText: fullText,
        blocks: blocks,
        averageConfidence: avgConfidence,
        hasLowConfidence: avgConfidence < 0.75,
      );
    } catch (e) {
      throw OcrException('OCR 辨識失敗：$e');
    }
  }

  // ── 批次辨識（相簿多選） ──────────────────────────────────
  Future<List<OcrResult>> recognizeMultiple(
    List<String> imagePaths, {
    void Function(int current, int total)? onProgress,
  }) async {
    final results = <OcrResult>[];

    for (int i = 0; i < imagePaths.length; i++) {
      final result = await recognizeText(imagePaths[i]);
      results.add(result);
      onProgress?.call(i + 1, imagePaths.length);
    }

    return results;
  }

  void dispose() {
    _recognizer.close();
  }
}

// ── 資料類別 ──────────────────────────────────────────────
class OcrResult {
  final String fullText;
  final List<OcrBlock> blocks;
  final double averageConfidence;
  final bool hasLowConfidence;

  OcrResult({
    required this.fullText,
    required this.blocks,
    required this.averageConfidence,
    required this.hasLowConfidence,
  });
}

class OcrBlock {
  final String text;
  final double confidence;

  OcrBlock({required this.text, required this.confidence});

  bool get isLowConfidence => confidence < 0.75;
}

class OcrException implements Exception {
  final String message;
  OcrException(this.message);

  @override
  String toString() => message;
}
