import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ocr_notes_app/models/image_preprocess.dart';
import 'package:ocr_notes_app/models/llm_note_result.dart';
import 'package:ocr_notes_app/models/scan_page.dart';
import 'package:ocr_notes_app/models/scan_session.dart';
import 'package:ocr_notes_app/screens/proofreading_screen.dart';
import 'package:ocr_notes_app/services/ocr_service.dart';
import 'package:ocr_notes_app/services/scan_pipeline_service.dart';

void main() {
  testWidgets('switches between OCR pages in proofreading screen',
      (tester) async {
    final pages = [
      _pageDraft(index: 0, text: '第一頁文字'),
      _pageDraft(index: 1, text: '第二頁文字'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: ProofreadingScreen(
          imagePath: '/tmp/processed-1.jpg',
          ocrResult: pages.first.ocrResult!,
          pages: pages,
        ),
      ),
    );

    expect(find.text('第 1 頁'), findsOneWidget);
    expect(find.text('第 2 頁'), findsOneWidget);
    expect(find.text('辨識文字 1/2'), findsOneWidget);
    expect(find.text('第一頁文字'), findsOneWidget);
    expect(find.text('第二頁文字'), findsNothing);

    await tester.tap(find.text('第 2 頁'));
    await tester.pumpAndSettle();

    expect(find.text('辨識文字 2/2'), findsOneWidget);
    expect(find.text('第二頁文字'), findsOneWidget);
  });

  testWidgets('previews AI result before applying it to editor',
      (tester) async {
    final completer = Completer<LlmNoteResult>();
    final pages = [_pageDraft(index: 0, text: '原始校對文字')];

    await tester.pumpWidget(
      MaterialApp(
        home: ProofreadingScreen(
          imagePath: '/tmp/processed-1.jpg',
          ocrResult: pages.first.ocrResult!,
          pages: pages,
          scanSession: _scanSession(),
          aiOrganizer: ({required session, required pages, required options}) {
            expect(pages.single.cleanedOcrText, '原始校對文字');
            expect(options['organize_mode'], 'general_note');
            expect(options['translate_enabled'], isFalse);
            return completer.future;
          },
        ),
      ),
    );

    await tester.tap(find.text('AI 整理'));
    await tester.pumpAndSettle();
    expect(find.text('AI 整理方式'), findsOneWidget);

    await tester.tap(find.text('開始整理'));
    await tester.pump();

    expect(find.text('取消 AI'), findsOneWidget);
    expect(find.text('原始校對文字'), findsOneWidget);

    completer.complete(_llmResult());
    await tester.pumpAndSettle();

    expect(find.text('AI 整理預覽'), findsOneWidget);
    expect(find.text('AI 標題'), findsOneWidget);
    expect(find.text('原始校對文字'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('請確認低信心文字'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('請確認低信心文字'), findsOneWidget);

    await tester.tap(find.text('套用全部'));
    await tester.pumpAndSettle();

    expect(find.text('新增筆記'), findsOneWidget);
    expect(find.textContaining('AI 摘要'), findsOneWidget);
    expect(find.textContaining('AI 整理內容'), findsOneWidget);
    expect(find.text('AI 標題'), findsOneWidget);
  });

  testWidgets('keeps OCR text when AI organize fails', (tester) async {
    final pages = [_pageDraft(index: 0, text: '人工校對後文字')];

    await tester.pumpWidget(
      MaterialApp(
        home: ProofreadingScreen(
          imagePath: '/tmp/processed-1.jpg',
          ocrResult: pages.first.ocrResult!,
          pages: pages,
          scanSession: _scanSession(),
          aiOrganizer: (
              {required session, required pages, required options}) async {
            throw Exception('backend offline');
          },
        ),
      ),
    );

    await tester.tap(find.text('AI 整理'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('開始整理'));
    await tester.pumpAndSettle();

    expect(find.textContaining('AI 整理失敗'), findsOneWidget);
    expect(find.text('人工校對後文字'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確認文字'));
    await tester.pumpAndSettle();

    expect(find.text('新增筆記'), findsOneWidget);
    expect(find.text('人工校對後文字'), findsOneWidget);
    expect(find.text('AI 整理內容'), findsNothing);
  });
}

ScanSession _scanSession() {
  final now = DateTime.now();
  return ScanSession(
    id: 1,
    status: 'ready_for_proofreading',
    source: 'gallery',
    pageCount: 1,
    createdAt: now,
    updatedAt: now,
  );
}

LlmNoteResult _llmResult() {
  return LlmNoteResult(
    sessionId: 1,
    taskType: 'organize_note',
    promptVersion: 'prompt-v1',
    modelName: 'mock-llm',
    inputHash: 'hash',
    title: 'AI 標題',
    summary: 'AI 摘要',
    organizedContent: 'AI 整理內容',
    tagsJson: '["筆記","AI"]',
    warningsJson: '["請確認低信心文字"]',
    status: 'success',
    createdAt: DateTime.now(),
  );
}

ScanPageDraft _pageDraft({required int index, required String text}) {
  final processedPath = '/tmp/processed-$index.jpg';
  final originalPath = '/tmp/original-$index.jpg';

  return ScanPageDraft(
    page: ScanPage(
      sessionId: 1,
      pageIndex: index,
      originalImagePath: originalPath,
      processedImagePath: processedPath,
      preprocessProfile: 'auto_document',
      rawOcrText: text,
      cleanedOcrText: text,
      averageConfidence: 0.9,
      lowConfidenceCount: 0,
    ),
    preprocessResult: ImagePreprocessResult(
      originalImagePath: originalPath,
      processedImagePath: processedPath,
      profile: ImagePreprocessProfile.autoDocument,
      wasProcessed: true,
      usedFallback: false,
      metadata: const {},
    ),
    ocrResult: OcrResult(
      fullText: text,
      blocks: [
        OcrBlock(
          blockIndex: 0,
          text: text,
          confidence: 0.9,
        ),
      ],
      averageConfidence: 0.9,
      hasLowConfidence: false,
      imagePath: processedPath,
      originalImagePath: originalPath,
      processedImagePath: processedPath,
      pageIndex: index,
    ),
  );
}
