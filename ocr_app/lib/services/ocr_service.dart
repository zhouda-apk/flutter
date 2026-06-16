import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Rect;

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
  Future<OcrResult> recognizeText(
    String imagePath, {
    String? originalImagePath,
    int? pageIndex,
    Map<String, Object?> metadata = const {},
  }) async {
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
      final orderedBlockDrafts = _sortBlocksByReadingOrder(
        recognized.blocks.indexed.map((entry) {
          final (index, block) = entry;
          final elements = block.lines.expand((l) => l.elements).toList();
          final avgConfidence = elements.isEmpty
              ? 0.0
              : elements
                      .map((e) => e.confidence ?? 0.0)
                      .reduce((a, b) => a + b) /
                  elements.length;

          return _OcrBlockDraft(
            originalIndex: index,
            text: _orderedBlockText(block),
            confidence: avgConfidence,
            boundingBox: block.boundingBox,
            boundingBoxJson: _boundingBoxToJson(block.boundingBox),
            fragments: _orderedBlockFragments(block),
          );
        }).toList(),
      );

      final blocks = orderedBlockDrafts.indexed.map((entry) {
        final (index, block) = entry;
        return OcrBlock(
          blockIndex: index,
          text: block.text,
          confidence: block.confidence,
          boundingBoxJson: block.boundingBoxJson,
          fragments: block.fragments,
        );
      }).toList();

      // 保留所有 block，低信心內容交由校對頁與後續 pipeline 標記。
      final fullText = _cleanOcrText(
        blocks.isEmpty ? recognized.text : blocks.map((b) => b.text).join('\n'),
      );

      final avgConfidence = blocks.isEmpty
          ? 0.0
          : blocks.map((b) => b.confidence).reduce((a, b) => a + b) /
              blocks.length;
      final lowConfidenceCount = blocks.where((b) => b.isLowConfidence).length;

      return OcrResult(
        rawText: recognized.text,
        fullText: fullText,
        blocks: blocks,
        averageConfidence: avgConfidence,
        hasLowConfidence: avgConfidence < 0.70 || lowConfidenceCount > 0,
        lowConfidenceBlockCount: lowConfidenceCount,
        imagePath: imagePath,
        originalImagePath: originalImagePath ?? imagePath,
        processedImagePath: imagePath,
        pageIndex: pageIndex,
        metadata: metadata,
      );
    } catch (e) {
      throw OcrException('OCR 辨識失敗：$e');
    }
  }

  String _boundingBoxToJson(Object? rect) {
    if (rect == null) return '{}';
    try {
      final dynamic value = rect;
      return jsonEncode({
        'left': value.left,
        'top': value.top,
        'right': value.right,
        'bottom': value.bottom,
      });
    } catch (_) {
      return '{}';
    }
  }

  List<_OcrBlockDraft> _sortBlocksByReadingOrder(
    List<_OcrBlockDraft> blocks,
  ) {
    final ordered = List<_OcrBlockDraft>.of(blocks);
    ordered.sort((a, b) {
      final byLayout = _compareRectsReadingOrder(a.boundingBox, b.boundingBox);
      if (byLayout != 0) return byLayout;
      return a.originalIndex.compareTo(b.originalIndex);
    });
    return ordered;
  }

  String _orderedBlockText(TextBlock block) {
    final lines = List<TextLine>.of(block.lines)
      ..sort((a, b) => _compareRectsReadingOrder(a.boundingBox, b.boundingBox));

    final text = lines
        .map((line) => line.text.trim())
        .where((line) => line.isNotEmpty)
        .join('\n')
        .trim();

    return text.isEmpty ? block.text.trim() : text;
  }

  List<OcrTextFragment> _orderedBlockFragments(TextBlock block) {
    final lines = List<TextLine>.of(block.lines)
      ..sort((a, b) => _compareRectsReadingOrder(a.boundingBox, b.boundingBox));

    final fragments = <OcrTextFragment>[];
    for (final line in lines) {
      final elements = List<TextElement>.of(line.elements)
        ..sort(
          (a, b) => _compareRectsReadingOrder(a.boundingBox, b.boundingBox),
        );

      if (elements.isEmpty) {
        final text = line.text.trim();
        if (text.isNotEmpty) {
          fragments.add(OcrTextFragment(text: text, confidence: 1.0));
          fragments.add(const OcrTextFragment(text: '\n', confidence: 1.0));
        }
        continue;
      }

      for (var i = 0; i < elements.length; i++) {
        final element = elements[i];
        final text = element.text.trim();
        if (text.isEmpty) continue;
        fragments.add(
          OcrTextFragment(
            text: text,
            confidence: element.confidence ?? 1.0,
          ),
        );
        if (i < elements.length - 1) {
          fragments.add(const OcrTextFragment(text: ' ', confidence: 1.0));
        }
      }
      fragments.add(const OcrTextFragment(text: '\n', confidence: 1.0));
    }

    if (fragments.isNotEmpty && fragments.last.text == '\n') {
      fragments.removeLast();
    }
    return fragments;
  }

  int _compareRectsReadingOrder(Rect? a, Rect? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;

    final centerDeltaY = (a.center.dy - b.center.dy).abs();
    final averageHeight = (a.height + b.height) / 2;
    final rowTolerance = math.max(8.0, averageHeight * 0.45);
    final overlapsVertically = a.top <= b.bottom && b.top <= a.bottom;
    final sameReadingRow = overlapsVertically || centerDeltaY <= rowTolerance;

    if (sameReadingRow) {
      final leftDelta = a.left - b.left;
      if (leftDelta.abs() > 4) return leftDelta.sign.toInt();
      final topDelta = a.top - b.top;
      if (topDelta.abs() > 4) return topDelta.sign.toInt();
      return 0;
    }

    final topDelta = a.top - b.top;
    if (topDelta.abs() > 4) return topDelta.sign.toInt();

    final leftDelta = a.left - b.left;
    if (leftDelta.abs() > 4) return leftDelta.sign.toInt();
    return 0;
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
  final String rawText;
  final String fullText;
  final List<OcrBlock> blocks;
  final double averageConfidence;
  final bool hasLowConfidence;
  final int lowConfidenceBlockCount;
  final String? imagePath;
  final String? originalImagePath;
  final String? processedImagePath;
  final int? pageIndex;
  final Map<String, Object?> metadata;

  OcrResult({
    String? rawText,
    required this.fullText,
    required this.blocks,
    required this.averageConfidence,
    required this.hasLowConfidence,
    int? lowConfidenceBlockCount,
    this.imagePath,
    this.originalImagePath,
    this.processedImagePath,
    this.pageIndex,
    this.metadata = const {},
  })  : rawText = rawText ?? fullText,
        lowConfidenceBlockCount = lowConfidenceBlockCount ??
            blocks.where((b) => b.isLowConfidence).length;

  OcrResult copyWith({
    String? rawText,
    String? fullText,
    List<OcrBlock>? blocks,
    double? averageConfidence,
    bool? hasLowConfidence,
    int? lowConfidenceBlockCount,
    String? imagePath,
    String? originalImagePath,
    String? processedImagePath,
    int? pageIndex,
    Map<String, Object?>? metadata,
  }) {
    return OcrResult(
      rawText: rawText ?? this.rawText,
      fullText: fullText ?? this.fullText,
      blocks: blocks ?? this.blocks,
      averageConfidence: averageConfidence ?? this.averageConfidence,
      hasLowConfidence: hasLowConfidence ?? this.hasLowConfidence,
      lowConfidenceBlockCount:
          lowConfidenceBlockCount ?? this.lowConfidenceBlockCount,
      imagePath: imagePath ?? this.imagePath,
      originalImagePath: originalImagePath ?? this.originalImagePath,
      processedImagePath: processedImagePath ?? this.processedImagePath,
      pageIndex: pageIndex ?? this.pageIndex,
      metadata: metadata ?? this.metadata,
    );
  }
}

class _OcrBlockDraft {
  final int originalIndex;
  final String text;
  final double confidence;
  final Rect? boundingBox;
  final String boundingBoxJson;
  final List<OcrTextFragment> fragments;

  const _OcrBlockDraft({
    required this.originalIndex,
    required this.text,
    required this.confidence,
    required this.boundingBox,
    required this.boundingBoxJson,
    this.fragments = const [],
  });
}

class OcrTextFragment {
  final String text;
  final double confidence;

  const OcrTextFragment({
    required this.text,
    required this.confidence,
  });

  bool get isLowConfidence => confidence < 0.75;
}

class OcrBlock {
  final int blockIndex;
  final String text;
  final double confidence;
  final String boundingBoxJson;
  final List<OcrTextFragment> fragments;

  OcrBlock({
    this.blockIndex = 0,
    required this.text,
    required this.confidence,
    this.boundingBoxJson = '{}',
    this.fragments = const [],
  });

  bool get isLowConfidence =>
      confidence < 0.75 ||
      fragments.any((fragment) => fragment.isLowConfidence);
}

class OcrException implements Exception {
  final String message;
  OcrException(this.message);

  @override
  String toString() => message;
}
