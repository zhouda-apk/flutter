import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ocr_notes_app/database/database_helper.dart';
import 'package:ocr_notes_app/models/scan_page.dart';
import 'package:ocr_notes_app/models/scan_session.dart';
import 'package:ocr_notes_app/repositories/note_repository.dart';
import 'package:ocr_notes_app/services/llm_backend_client.dart';
import 'package:ocr_notes_app/services/note_ai_service.dart';

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
    tempDir = await Directory.systemTemp.createTemp('note_ai_service_test_');
    dbPath = p.join(tempDir.path, 'note_ai_service_test.db');
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

  test('organizes OCR pages and stores LLM output without image paths',
      () async {
    final session = await _createSession(repository);
    await _createPage(
      repository,
      sessionId: session.id!,
      pageIndex: 1,
      text: '第二頁重點',
      imagePath: '/tmp/secret-page-2.jpg',
    );
    await _createPage(
      repository,
      sessionId: session.id!,
      pageIndex: 0,
      text: '第一頁重點',
      imagePath: '/tmp/secret-page-1.jpg',
    );

    late Map<String, dynamic> requestBody;
    final client = LlmBackendClient(
      baseUri: Uri.parse('https://backend.example.com'),
      mockMode: false,
      httpClient: MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'title': 'AI 標題',
            'summary': 'AI 摘要',
            'organized_content': 'AI 整理內容',
            'tags': ['筆記'],
            'warnings': <String>[],
            'model_name': 'test-model',
            'prompt_version': 'prompt-v1',
          })),
          200,
        );
      }),
    );
    final service = NoteAiService(repository: repository, client: client);

    final output = await service.organizeScanSession(session.id!);

    expect(output.status, 'success');
    expect(output.title, 'AI 標題');
    expect(output.promptVersion, 'prompt-v1');

    final outputs = await repository.getLlmOutputsForSession(session.id!);
    expect(outputs, hasLength(1));
    expect(outputs.first.organizedContent, 'AI 整理內容');

    final encodedBody = jsonEncode(requestBody);
    expect(encodedBody, contains('第一頁重點'));
    expect(encodedBody, contains('第二頁重點'));
    expect(encodedBody, isNot(contains('/tmp/secret-page-1.jpg')));
    expect(encodedBody, isNot(contains('/tmp/secret-page-2.jpg')));
    final firstPage =
        (requestBody['pages'] as List<dynamic>).first as Map<String, dynamic>;
    expect(firstPage.containsKey('original_image_path'), isFalse);
    expect(firstPage.containsKey('processed_image_path'), isFalse);
  });

  test('timeout stores failed LLM output and keeps OCR pages unchanged',
      () async {
    final session = await _createSession(repository);
    final page = await _createPage(
      repository,
      sessionId: session.id!,
      pageIndex: 0,
      text: '原始 OCR 文字',
      imagePath: '/tmp/page.jpg',
    );
    final client = LlmBackendClient(
      baseUri: Uri.parse('https://backend.example.com'),
      mockMode: false,
      timeout: const Duration(milliseconds: 5),
      httpClient: MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response('{}', 200);
      }),
    );
    final service = NoteAiService(repository: repository, client: client);

    await expectLater(
      service.organizeScanSession(session.id!),
      throwsA(
        isA<LlmBackendException>().having(
          (e) => e.type,
          'type',
          LlmBackendErrorType.timeout,
        ),
      ),
    );

    final pages = await repository.getScanPagesForSession(session.id!);
    expect(pages.single.id, page.id);
    expect(pages.single.cleanedOcrText, '原始 OCR 文字');

    final outputs = await repository.getLlmOutputsForSession(session.id!);
    expect(outputs, hasLength(1));
    expect(outputs.first.status, 'failed');
    expect(outputs.first.errorMessage, contains('逾時'));
  });
}

Future<ScanSession> _createSession(NoteRepository repository) {
  final now = DateTime.now();
  return repository.insertScanSession(
    ScanSession(
      status: 'ready_for_proofreading',
      source: 'gallery',
      pageCount: 2,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

Future<ScanPage> _createPage(
  NoteRepository repository, {
  required int sessionId,
  required int pageIndex,
  required String text,
  required String imagePath,
}) {
  return repository.insertScanPage(
    ScanPage(
      sessionId: sessionId,
      pageIndex: pageIndex,
      originalImagePath: imagePath,
      processedImagePath: imagePath.replaceFirst('.jpg', '_processed.jpg'),
      preprocessProfile: 'auto_document',
      rawOcrText: text,
      cleanedOcrText: text,
      averageConfidence: 0.88,
      lowConfidenceCount: 0,
    ),
  );
}
