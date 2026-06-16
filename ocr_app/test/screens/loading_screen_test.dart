import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ocr_notes_app/models/image_preprocess.dart';
import 'package:ocr_notes_app/models/scan_page.dart';
import 'package:ocr_notes_app/models/scan_session.dart';
import 'package:ocr_notes_app/screens/loading_screen.dart';
import 'package:ocr_notes_app/services/ocr_service.dart';
import 'package:ocr_notes_app/services/scan_pipeline_service.dart';

void main() {
  testWidgets('shows pipeline progress message while loading', (tester) async {
    final completer = Completer<ScanPipelineResult>();

    await tester.pumpWidget(
      MaterialApp(
        home: LoadingScreen(
          imagePath: '/tmp/page.jpg',
          pipelineRunner: (
            imagePaths, {
            required source,
            required onProgress,
          }) async {
            onProgress(
              const ScanPipelineProgress(
                progress: 0.2,
                stage: 'preprocess',
                message: '正在優化圖片',
              ),
            );
            return completer.future;
          },
        ),
      ),
    );

    await tester.pump();

    expect(find.text('正在優化圖片'), findsOneWidget);
    expect(find.text('20%'), findsOneWidget);

    completer.complete(_pipelineResult());
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('掃描結果總覽'), findsOneWidget);
    expect(find.text('第 1 頁'), findsOneWidget);
  });
}

ScanPipelineResult _pipelineResult() {
  final now = DateTime.now();
  final session = ScanSession(
    id: 1,
    status: 'ready_for_proofreading',
    source: 'camera',
    pageCount: 1,
    createdAt: now,
    updatedAt: now,
  );
  const page = ScanPage(
    id: 1,
    sessionId: 1,
    pageIndex: 0,
    originalImagePath: '/tmp/page.jpg',
    processedImagePath: '/tmp/page_processed.jpg',
    preprocessProfile: 'auto_document',
    rawOcrText: 'OCR text',
    cleanedOcrText: 'OCR text',
    averageConfidence: 0.9,
    lowConfidenceCount: 0,
  );
  final preprocess = ImagePreprocessResult(
    originalImagePath: page.originalImagePath,
    processedImagePath: page.processedImagePath,
    profile: ImagePreprocessProfile.autoDocument,
    wasProcessed: true,
    usedFallback: false,
    metadata: const {},
  );
  final ocr = OcrResult(
    rawText: 'OCR text',
    fullText: 'OCR text',
    blocks: [
      OcrBlock(
        blockIndex: 0,
        text: 'OCR text',
        confidence: 0.9,
      ),
    ],
    averageConfidence: 0.9,
    hasLowConfidence: false,
    imagePath: page.processedImagePath,
    originalImagePath: page.originalImagePath,
    processedImagePath: page.processedImagePath,
    pageIndex: 0,
  );

  return ScanPipelineResult(
    session: session,
    pages: [
      ScanPageDraft(
        page: page,
        preprocessResult: preprocess,
        ocrResult: ocr,
      ),
    ],
  );
}
