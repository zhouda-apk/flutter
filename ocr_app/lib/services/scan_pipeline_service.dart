import 'dart:convert';

import '../models/image_preprocess.dart';
import '../models/ocr_block_record.dart';
import '../models/scan_page.dart';
import '../models/scan_session.dart';
import '../repositories/note_repository.dart';
import 'image_preprocess_service.dart';
import 'ocr_service.dart';

typedef ImagePreprocessRunner = Future<ImagePreprocessResult> Function(
  ImagePreprocessRequest request,
);

typedef OcrTextRecognizer = Future<OcrResult> Function(
  String imagePath, {
  String? originalImagePath,
  int? pageIndex,
  Map<String, Object?> metadata,
});

class ScanPipelineService {
  final NoteRepository _repository;
  final ImagePreprocessRunner _preprocess;
  late final OcrTextRecognizer _recognizeText;
  final OcrService? _ownedOcrService;

  ScanPipelineService({
    NoteRepository? repository,
    ImagePreprocessService? imagePreprocessService,
    OcrService? ocrService,
    ImagePreprocessRunner? preprocess,
    OcrTextRecognizer? recognizeText,
  })  : _repository = repository ?? NoteRepository(),
        _preprocess = preprocess ??
            (imagePreprocessService ?? ImagePreprocessService()).preprocess,
        _ownedOcrService =
            recognizeText == null && ocrService == null ? OcrService() : null {
    _recognizeText =
        recognizeText ?? (ocrService ?? _ownedOcrService!).recognizeText;
  }

  Future<ScanPipelineResult> processSingleImage(
    String imagePath, {
    String source = 'camera',
    ImagePreprocessProfile profile = ImagePreprocessProfile.autoDocument,
    void Function(ScanPipelineProgress progress)? onProgress,
  }) {
    return processImages(
      [imagePath],
      source: source,
      profile: profile,
      onProgress: onProgress,
    );
  }

  Future<ScanPipelineResult> processImages(
    List<String> imagePaths, {
    String source = 'gallery',
    ImagePreprocessProfile profile = ImagePreprocessProfile.autoDocument,
    void Function(ScanPipelineProgress progress)? onProgress,
  }) async {
    if (imagePaths.isEmpty) {
      throw const ScanPipelineException('沒有可處理的圖片');
    }

    final now = DateTime.now();
    var session = await _repository.insertScanSession(
      ScanSession(
        status: 'processing',
        source: source,
        pageCount: imagePaths.length,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final pages = <ScanPageDraft>[];
    _emit(onProgress, 0.02, 'created_session', '建立掃描任務');

    for (var i = 0; i < imagePaths.length; i++) {
      final pageProgressBase = i / imagePaths.length;
      final pageProgressSpan = 1 / imagePaths.length;

      try {
        _emit(
          onProgress,
          0.05 + pageProgressBase * 0.75,
          'preprocess',
          '正在優化第 ${i + 1} / ${imagePaths.length} 頁圖片',
          currentPage: i + 1,
          totalPages: imagePaths.length,
        );

        final preprocessResult = await _preprocess(
          ImagePreprocessRequest(
            sourceImagePath: imagePaths[i],
            profile: profile,
          ),
        );

        _emit(
          onProgress,
          0.20 + pageProgressBase * 0.75 + pageProgressSpan * 0.20,
          'ocr',
          '正在辨識第 ${i + 1} / ${imagePaths.length} 頁文字',
          currentPage: i + 1,
          totalPages: imagePaths.length,
        );

        final ocrResult = await _recognizeText(
          preprocessResult.processedImagePath,
          originalImagePath: preprocessResult.originalImagePath,
          pageIndex: i,
          metadata: preprocessResult.metadata,
        );
        final normalizedOcrResult = ocrResult.copyWith(
          imagePath: preprocessResult.processedImagePath,
          originalImagePath: preprocessResult.originalImagePath,
          processedImagePath: preprocessResult.processedImagePath,
          pageIndex: i,
          metadata: {
            ...preprocessResult.metadata,
            ...ocrResult.metadata,
          },
        );

        final scanPage = await _repository.insertScanPage(
          ScanPage(
            sessionId: session.id!,
            pageIndex: i,
            originalImagePath: preprocessResult.originalImagePath,
            processedImagePath: preprocessResult.processedImagePath,
            preprocessProfile: preprocessResult.profile.value,
            rawOcrText: normalizedOcrResult.rawText,
            cleanedOcrText: normalizedOcrResult.fullText,
            averageConfidence: normalizedOcrResult.averageConfidence,
            lowConfidenceCount: normalizedOcrResult.lowConfidenceBlockCount,
            metadataJson: jsonEncode({
              ...preprocessResult.metadata,
              'ocr_average_confidence': normalizedOcrResult.averageConfidence,
              'ocr_text_length': normalizedOcrResult.fullText.length,
              'ocr_block_count': normalizedOcrResult.blocks.length,
            }),
          ),
        );

        for (final block in normalizedOcrResult.blocks) {
          await _repository.insertOcrBlock(
            OcrBlockRecord(
              pageId: scanPage.id!,
              blockIndex: block.blockIndex,
              text: block.text,
              confidence: block.confidence,
              boundingBoxJson: block.boundingBoxJson,
              isLowConfidence: block.isLowConfidence,
            ),
          );
        }

        pages.add(
          ScanPageDraft(
            page: scanPage,
            preprocessResult: preprocessResult,
            ocrResult: normalizedOcrResult,
          ),
        );
      } catch (e) {
        final failedPreprocess = ImagePreprocessResult(
          originalImagePath: imagePaths[i],
          processedImagePath: imagePaths[i],
          profile: profile,
          wasProcessed: false,
          usedFallback: true,
          metadata: {
            'profile': profile.value,
            'fallback': true,
            'pipeline_error': true,
          },
          errorMessage: e.toString(),
        );
        final failedPage = await _repository.insertScanPage(
          ScanPage(
            sessionId: session.id!,
            pageIndex: i,
            originalImagePath: imagePaths[i],
            processedImagePath: imagePaths[i],
            preprocessProfile: profile.value,
            rawOcrText: '',
            cleanedOcrText: '',
            averageConfidence: 0,
            lowConfidenceCount: 0,
            metadataJson: jsonEncode({
              'pipeline_error': true,
              'error_message': e.toString(),
            }),
          ),
        );
        pages.add(
          ScanPageDraft(
            page: failedPage,
            preprocessResult: failedPreprocess,
            errorMessage: e.toString(),
          ),
        );
      }
    }

    final successCount = pages.where((p) => p.isSuccess).length;
    final updatedAt = DateTime.now();
    session = await _repository.updateScanSession(
      session.copyWith(
        status: successCount == 0 ? 'failed' : 'ready_for_proofreading',
        updatedAt: updatedAt,
        errorMessage: successCount == 0 ? '所有頁面 OCR 皆失敗' : null,
      ),
    );

    _emit(
      onProgress,
      1.0,
      'completed',
      successCount == 0 ? '辨識失敗' : '辨識完成',
    );

    if (successCount == 0) {
      throw const ScanPipelineException('OCR 辨識失敗：所有頁面皆無法處理');
    }

    return ScanPipelineResult(session: session, pages: pages);
  }

  Future<ScanPageDraft> replacePageImage({
    required ScanSession session,
    required ScanPageDraft currentPage,
    required String imagePath,
    ImagePreprocessProfile profile = ImagePreprocessProfile.autoDocument,
    void Function(ScanPipelineProgress progress)? onProgress,
  }) async {
    final sessionId = session.id;
    if (sessionId == null) {
      throw const ScanPipelineException('掃描任務尚未保存，無法替換頁面');
    }

    final pageIndex = currentPage.page.pageIndex;
    try {
      _emit(
        onProgress,
        0.20,
        'preprocess',
        '正在優化第 ${pageIndex + 1} 頁圖片',
        currentPage: pageIndex + 1,
        totalPages: session.pageCount,
      );

      final preprocessResult = await _preprocess(
        ImagePreprocessRequest(
          sourceImagePath: imagePath,
          profile: profile,
        ),
      );

      _emit(
        onProgress,
        0.58,
        'ocr',
        '正在重新辨識第 ${pageIndex + 1} 頁文字',
        currentPage: pageIndex + 1,
        totalPages: session.pageCount,
      );

      final ocrResult = await _recognizeText(
        preprocessResult.processedImagePath,
        originalImagePath: preprocessResult.originalImagePath,
        pageIndex: pageIndex,
        metadata: preprocessResult.metadata,
      );
      final normalizedOcrResult = ocrResult.copyWith(
        imagePath: preprocessResult.processedImagePath,
        originalImagePath: preprocessResult.originalImagePath,
        processedImagePath: preprocessResult.processedImagePath,
        pageIndex: pageIndex,
        metadata: {
          ...preprocessResult.metadata,
          ...ocrResult.metadata,
        },
      );

      final updatedPage = currentPage.page.copyWith(
        sessionId: sessionId,
        pageIndex: pageIndex,
        originalImagePath: preprocessResult.originalImagePath,
        processedImagePath: preprocessResult.processedImagePath,
        preprocessProfile: preprocessResult.profile.value,
        rawOcrText: normalizedOcrResult.rawText,
        cleanedOcrText: normalizedOcrResult.fullText,
        averageConfidence: normalizedOcrResult.averageConfidence,
        lowConfidenceCount: normalizedOcrResult.lowConfidenceBlockCount,
        metadataJson: jsonEncode({
          ...preprocessResult.metadata,
          'ocr_average_confidence': normalizedOcrResult.averageConfidence,
          'ocr_text_length': normalizedOcrResult.fullText.length,
          'ocr_block_count': normalizedOcrResult.blocks.length,
          'replaced_at': DateTime.now().toIso8601String(),
        }),
      );

      final savedPage = await _saveReplacementPage(updatedPage);
      for (final block in normalizedOcrResult.blocks) {
        await _repository.insertOcrBlock(
          OcrBlockRecord(
            pageId: savedPage.id!,
            blockIndex: block.blockIndex,
            text: block.text,
            confidence: block.confidence,
            boundingBoxJson: block.boundingBoxJson,
            isLowConfidence: block.isLowConfidence,
          ),
        );
      }

      await _repository.updateScanSession(
        session.copyWith(
          status: 'ready_for_proofreading',
          updatedAt: DateTime.now(),
        ),
      );

      _emit(
        onProgress,
        1.0,
        'completed',
        '第 ${pageIndex + 1} 頁已更新',
        currentPage: pageIndex + 1,
        totalPages: session.pageCount,
      );

      return ScanPageDraft(
        page: savedPage,
        preprocessResult: preprocessResult,
        ocrResult: normalizedOcrResult,
      );
    } catch (e) {
      final failedPreprocess = ImagePreprocessResult(
        originalImagePath: imagePath,
        processedImagePath: imagePath,
        profile: profile,
        wasProcessed: false,
        usedFallback: true,
        metadata: {
          'profile': profile.value,
          'fallback': true,
          'pipeline_error': true,
        },
        errorMessage: e.toString(),
      );
      final failedPage = await _saveReplacementPage(
        currentPage.page.copyWith(
          originalImagePath: imagePath,
          processedImagePath: imagePath,
          rawOcrText: '',
          cleanedOcrText: '',
          averageConfidence: 0,
          lowConfidenceCount: 0,
          metadataJson: jsonEncode({
            'pipeline_error': true,
            'error_message': e.toString(),
            'replaced_at': DateTime.now().toIso8601String(),
          }),
        ),
      );
      return ScanPageDraft(
        page: failedPage,
        preprocessResult: failedPreprocess,
        errorMessage: e.toString(),
      );
    }
  }

  Future<ScanPage> _saveReplacementPage(ScanPage page) async {
    final pageId = page.id;
    if (pageId == null) {
      return _repository.insertScanPage(page);
    }
    await _repository.deleteOcrBlocksForPage(pageId);
    return _repository.updateScanPage(page);
  }

  void dispose() {
    _ownedOcrService?.dispose();
  }

  void _emit(
    void Function(ScanPipelineProgress progress)? onProgress,
    double value,
    String stage,
    String message, {
    int? currentPage,
    int? totalPages,
  }) {
    onProgress?.call(
      ScanPipelineProgress(
        progress: value.clamp(0, 1).toDouble(),
        stage: stage,
        message: message,
        currentPage: currentPage,
        totalPages: totalPages,
      ),
    );
  }
}

class ScanPipelineProgress {
  final double progress;
  final String stage;
  final String message;
  final int? currentPage;
  final int? totalPages;

  const ScanPipelineProgress({
    required this.progress,
    required this.stage,
    required this.message,
    this.currentPage,
    this.totalPages,
  });
}

class ScanPipelineResult {
  final ScanSession session;
  final List<ScanPageDraft> pages;

  const ScanPipelineResult({
    required this.session,
    required this.pages,
  });

  List<ScanPageDraft> get successfulPages {
    return pages.where((p) => p.isSuccess).toList();
  }

  OcrResult get firstSuccessfulOcrResult {
    for (final page in successfulPages) {
      final result = page.ocrResult;
      if (result != null) return result;
    }
    throw const ScanPipelineException('沒有可用的 OCR 結果');
  }

  String get combinedText {
    return successfulPages
        .map((p) => p.ocrResult?.fullText.trim() ?? '')
        .where((text) => text.isNotEmpty)
        .join('\n\n');
  }
}

class ScanPageDraft {
  final ScanPage page;
  final ImagePreprocessResult preprocessResult;
  final OcrResult? ocrResult;
  final String? errorMessage;

  const ScanPageDraft({
    required this.page,
    required this.preprocessResult,
    this.ocrResult,
    this.errorMessage,
  });

  bool get isSuccess => ocrResult != null && errorMessage == null;
}

class ScanPipelineException implements Exception {
  final String message;

  const ScanPipelineException(this.message);

  @override
  String toString() => message;
}
