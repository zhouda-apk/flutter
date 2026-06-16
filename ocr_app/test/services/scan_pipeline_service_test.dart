import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ocr_notes_app/database/database_helper.dart';
import 'package:ocr_notes_app/models/image_preprocess.dart';
import 'package:ocr_notes_app/repositories/note_repository.dart';
import 'package:ocr_notes_app/services/ocr_service.dart';
import 'package:ocr_notes_app/services/scan_pipeline_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String dbPath;
  late DatabaseHelper helper;
  late NoteRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ocr_pipeline_test_');
    dbPath = p.join(tempDir.path, 'ocr_pipeline_test.db');
    helper = DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: dbPath,
    );
    repository = NoteRepository(databaseHelper: helper);
  });

  tearDown(() async {
    await helper.closeDB();
    await databaseFactoryFfi.deleteDatabase(dbPath);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('processes multiple images and stores pages and blocks', () async {
    final progressEvents = <ScanPipelineProgress>[];
    final service = ScanPipelineService(
      repository: repository,
      preprocess: _fakePreprocess,
      recognizeText: _fakeRecognize,
    );

    final result = await service.processImages(
      ['/tmp/page-1.jpg', '/tmp/page-2.jpg'],
      source: 'gallery',
      onProgress: progressEvents.add,
    );

    expect(result.session.id, isNotNull);
    expect(result.session.status, 'ready_for_proofreading');
    expect(result.pages, hasLength(2));
    expect(result.successfulPages, hasLength(2));
    expect(result.combinedText, contains('OCR text for page 0'));
    expect(result.combinedText, contains('OCR text for page 1'));
    expect(progressEvents.map((e) => e.stage), contains('preprocess'));
    expect(progressEvents.map((e) => e.stage), contains('ocr'));
    expect(progressEvents.last.stage, 'completed');

    final pages = await repository.getScanPagesForSession(result.session.id!);
    expect(pages, hasLength(2));
    expect(pages.first.originalImagePath, '/tmp/page-1.jpg');
    expect(pages.first.processedImagePath, '/tmp/page-1_processed.jpg');
    expect(pages.first.lowConfidenceCount, 1);

    final blocks = await repository.getOcrBlocksForPage(pages.first.id!);
    expect(blocks, hasLength(2));
    expect(blocks.first.blockIndex, 0);
    expect(blocks.last.isLowConfidence, isTrue);
  });

  test('keeps successful pages when one page fails', () async {
    final service = ScanPipelineService(
      repository: repository,
      preprocess: _fakePreprocess,
      recognizeText: (
        imagePath, {
        String? originalImagePath,
        int? pageIndex,
        Map<String, Object?> metadata = const {},
      }) {
        if (pageIndex == 1) {
          throw Exception('OCR failed');
        }
        return _fakeRecognize(
          imagePath,
          originalImagePath: originalImagePath,
          pageIndex: pageIndex,
          metadata: metadata,
        );
      },
    );

    final result = await service.processImages(
      ['/tmp/page-1.jpg', '/tmp/page-2.jpg'],
      source: 'gallery',
    );

    expect(result.session.status, 'ready_for_proofreading');
    expect(result.pages, hasLength(2));
    expect(result.successfulPages, hasLength(1));
    expect(result.pages.last.isSuccess, isFalse);
    expect(result.pages.last.errorMessage, contains('OCR failed'));

    final pages = await repository.getScanPagesForSession(result.session.id!);
    expect(pages, hasLength(2));
    expect(pages.last.cleanedOcrText, '');
  });

  test('throws when all pages fail', () async {
    final service = ScanPipelineService(
      repository: repository,
      preprocess: _fakePreprocess,
      recognizeText: (
        imagePath, {
        String? originalImagePath,
        int? pageIndex,
        Map<String, Object?> metadata = const {},
      }) async {
        throw Exception('OCR failed');
      },
    );

    expect(
      () => service.processImages(['/tmp/page-1.jpg']),
      throwsA(isA<ScanPipelineException>()),
    );
  });
}

Future<ImagePreprocessResult> _fakePreprocess(
  ImagePreprocessRequest request,
) async {
  return ImagePreprocessResult(
    originalImagePath: request.sourceImagePath,
    processedImagePath: request.sourceImagePath.replaceFirst(
      '.jpg',
      '_processed.jpg',
    ),
    profile: request.profile,
    wasProcessed: true,
    usedFallback: false,
    metadata: {
      'profile': request.profile.value,
      'fallback': false,
      'output_width': 100,
      'output_height': 60,
    },
  );
}

Future<OcrResult> _fakeRecognize(
  String imagePath, {
  String? originalImagePath,
  int? pageIndex,
  Map<String, Object?> metadata = const {},
}) async {
  final page = pageIndex ?? 0;
  return OcrResult(
    rawText: 'Raw OCR text for page $page',
    fullText: 'OCR text for page $page',
    blocks: [
      OcrBlock(
        blockIndex: 0,
        text: 'OCR text',
        confidence: 0.92,
        boundingBoxJson: '{"left":0}',
      ),
      OcrBlock(
        blockIndex: 1,
        text: 'for page $page',
        confidence: 0.50,
        boundingBoxJson: '{"left":10}',
      ),
    ],
    averageConfidence: 0.71,
    hasLowConfidence: true,
    lowConfidenceBlockCount: 1,
    imagePath: imagePath,
    originalImagePath: originalImagePath,
    processedImagePath: imagePath,
    pageIndex: page,
    metadata: metadata,
  );
}
