import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  TextRecognizer? _recognizer;
  Future<void>? _initFuture;
  bool _preferChinese = true;

  // ── 初始化 TextRecognizer（包含中文→通用自動降級） ──────
  Future<void> _ensureInitialized() {
    if (_recognizer != null) return Future.value();
    return _initFuture ??= _initialize(preferChinese: _preferChinese);
  }

  Future<void> _initialize({required bool preferChinese}) async {
    try {
      _recognizer?.close();
      _recognizer = null;

      if (preferChinese) {
        _recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
      } else {
        _recognizer = TextRecognizer();
      }
    } catch (e) {
      _recognizer?.close();
      _recognizer = null;
      _initFuture = null;
      throw OcrException('模型初始化失敗：$e');
    }
  }

  bool _looksLikeChineseModelMissing(Object e) {
    final s = e.toString();
    return s.contains('ChineseTextRecognizerOptions') ||
        s.contains('text-recognition-chinese') ||
        s.contains('TextRecognitionScript.chinese');
  }

  // ── 辨識單張圖片（含後處理優化） ─────────────────────────────
  Future<OcrResult> recognizeText(String imagePath) async {
    // 確保初始化完成
    await _ensureInitialized();

    final inputImage = InputImage.fromFilePath(imagePath);

    try {
      RecognizedText recognized;
      try {
        recognized = await _recognizer!.processImage(inputImage);
      } catch (e) {
        // 中文模型缺失/初始化失敗時，降級為通用模型再重試一次。
        if (_preferChinese && _looksLikeChineseModelMissing(e)) {
          debugPrint('中文模型不可用，改用通用模型：$e');
          _preferChinese = false;
          _initFuture = null;
          await _ensureInitialized();
          recognized = await _recognizer!.processImage(inputImage);
        } else {
          rethrow;
        }
      }

      // 計算每個 block 的置信度
      final blocks = recognized.blocks.map((block) {
        final elements = block.lines.expand((l) => l.elements).toList();
        final avgConfidence = elements.isEmpty
            ? 0.0
            : elements.map((e) => e.confidence ?? 0.0).reduce((a, b) => a + b) /
                elements.length;

        return OcrBlock(
          text: block.text.trim(),
          confidence: avgConfidence,
        );
      }).toList();

      // 🔑 優化1：過濾掉低置信度的塊（< 0.6）
      final highConfidenceBlocks =
          blocks.where((b) => b.confidence >= 0.6).toList();

      // 🔑 優化2：組合文本並清理
      final fullText = _cleanOcrText(
        highConfidenceBlocks.isEmpty
            ? recognized.text
            : highConfidenceBlocks.map((b) => b.text).join('\n'),
      );

      // 🔑 優化3：使用高置信度塊計算平均置信度
      final avgConfidence = highConfidenceBlocks.isEmpty
          ? 0.0
          : highConfidenceBlocks
                  .map((b) => b.confidence)
                  .reduce((a, b) => a + b) /
              highConfidenceBlocks.length;

      return OcrResult(
        fullText: fullText,
        blocks: highConfidenceBlocks,
        averageConfidence: avgConfidence,
        hasLowConfidence: avgConfidence < 0.70, // 提高塊臭閾值到 0.70
      );
    } catch (e) {
      throw OcrException('OCR 辨識失敗：$e');
    }
  }

  // ── 清理 OCR 文本（去除噪音、多餘空白） ──────────────────
  String _cleanOcrText(String text) {
    // 1. 去除多個連續空白和換行
    final cleaned = text
        .replaceAll(RegExp(r'\n\n+'), '\n') // 多個換行 → 單個換行
        .replaceAll(RegExp(r'  +'), ' ') // 多個空格 → 單個空格
        .trim();

    // 2. 去除不可見字符
    final lines = cleaned.split('\n');
    final validLines = lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && line.length > 1) // 過濾單字符行
        .toList();

    return validLines.join('\n');
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
    if (_recognizer != null) {
      try {
        _recognizer!.close();
      } catch (e) {
        debugPrint('釋放 OCR 資源時出錯：$e');
      }
      _recognizer = null;
    }
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
