import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ocr_notes_app/database/database_helper.dart';
import 'package:ocr_notes_app/models/llm_note_result.dart';
import 'package:ocr_notes_app/models/note.dart';
import 'package:ocr_notes_app/models/ocr_block_record.dart';
import 'package:ocr_notes_app/models/scan_page.dart';
import 'package:ocr_notes_app/models/scan_session.dart';
import 'package:ocr_notes_app/repositories/note_repository.dart';

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
    tempDir = await Directory.systemTemp.createTemp('ocr_notes_repo_test_');
    dbPath = p.join(tempDir.path, 'ocr_notes_test.db');
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

  test('migrates legacy notes table and keeps existing note data', () async {
    final legacyDb = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE notes (
              id       INTEGER PRIMARY KEY AUTOINCREMENT,
              title    TEXT NOT NULL,
              content  TEXT NOT NULL,
              raw_ocr_text TEXT NOT NULL,
              image_path   TEXT NOT NULL,
              tags         TEXT NOT NULL DEFAULT '',
              created_at   TEXT NOT NULL,
              updated_at   TEXT NOT NULL
            )
          ''');
          await db.insert('notes', {
            'title': 'Legacy',
            'content': 'legacy content',
            'raw_ocr_text': 'raw',
            'image_path': '/tmp/legacy.jpg',
            'tags': 'old,scan',
            'created_at': '2026-06-09T00:00:00.000',
            'updated_at': '2026-06-09T00:00:00.000',
          });
        },
      ),
    );
    await legacyDb.close();

    final migratedNote = await repository.getNoteById(1);
    expect(migratedNote, isNotNull);
    expect(migratedNote!.title, 'Legacy');
    expect(migratedNote.summary, '');
    expect(migratedNote.sourceType, 'single_image');
    expect(migratedNote.llmStatus, 'none');
    expect(migratedNote.tags, ['old', 'scan']);

    final db = await helper.database;
    final tableRows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final tables = tableRows.map((row) => row['name']).toSet();
    expect(tables, containsAll(['scan_sessions', 'scan_pages']));
    expect(tables, containsAll(['ocr_blocks', 'llm_outputs']));
  });

  test('inserts and reads notes through repository', () async {
    final now = DateTime(2026, 6, 9, 10, 30);

    final inserted = await repository.insertNote(
      Note(
        title: 'OCR Note',
        content: 'organized content',
        rawOcrText: 'raw content',
        imagePath: '/tmp/page.jpg',
        tags: const ['class', 'ocr'],
        summary: 'summary',
        sourceType: 'multi_page',
        llmStatus: 'success',
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(inserted.id, isNotNull);

    final notes = await repository.getAllNotes();
    expect(notes, hasLength(1));
    expect(notes.first.title, 'OCR Note');
    expect(notes.first.summary, 'summary');
    expect(notes.first.sourceType, 'multi_page');
    expect(notes.first.llmStatus, 'success');
    expect(notes.first.tags, ['class', 'ocr']);
  });

  test('stores scan session, pages, ocr blocks, and llm outputs', () async {
    final now = DateTime(2026, 6, 9, 11, 0);

    final session = await repository.insertScanSession(
      ScanSession(
        status: 'created',
        source: 'gallery',
        pageCount: 2,
        createdAt: now,
        updatedAt: now,
      ),
    );
    expect(session.id, isNotNull);

    final page = await repository.insertScanPage(
      ScanPage(
        sessionId: session.id!,
        pageIndex: 0,
        originalImagePath: '/tmp/original.jpg',
        processedImagePath: '/tmp/processed.jpg',
        preprocessProfile: 'auto_document',
        rawOcrText: 'raw page',
        cleanedOcrText: 'clean page',
        averageConfidence: 0.83,
        lowConfidenceCount: 1,
        metadataJson: '{"width":1200}',
      ),
    );
    expect(page.id, isNotNull);

    final block = await repository.insertOcrBlock(
      OcrBlockRecord(
        pageId: page.id!,
        blockIndex: 0,
        text: 'clean page',
        confidence: 0.74,
        boundingBoxJson: '{"left":1}',
        isLowConfidence: true,
      ),
    );
    expect(block.id, isNotNull);

    final output = await repository.insertLlmOutput(
      LlmNoteResult(
        sessionId: session.id!,
        taskType: 'organize_note',
        promptVersion: 'v1',
        modelName: 'mock-model',
        inputHash: 'hash',
        title: 'AI Title',
        summary: 'AI summary',
        organizedContent: 'AI content',
        tagsJson: '["ai"]',
        warningsJson: '[]',
        status: 'success',
        createdAt: now,
      ),
    );
    expect(output.id, isNotNull);

    final pages = await repository.getScanPagesForSession(session.id!);
    expect(pages, hasLength(1));
    expect(pages.first.cleanedOcrText, 'clean page');
    expect(pages.first.averageConfidence, 0.83);

    final blocks = await repository.getOcrBlocksForPage(page.id!);
    expect(blocks, hasLength(1));
    expect(blocks.first.isLowConfidence, isTrue);

    final outputs = await repository.getLlmOutputsForSession(session.id!);
    expect(outputs, hasLength(1));
    expect(outputs.first.title, 'AI Title');
  });

  test('reads session and notes after app restart', () async {
    final now = DateTime(2026, 6, 11, 9, 0);
    final session = await repository.insertScanSession(
      ScanSession(
        status: 'ready_for_proofreading',
        source: 'camera',
        pageCount: 1,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.insertScanPage(
      ScanPage(
        sessionId: session.id!,
        pageIndex: 0,
        originalImagePath: '/tmp/original.jpg',
        processedImagePath: '/tmp/processed.jpg',
        preprocessProfile: 'auto_document',
        rawOcrText: 'raw restart text',
        cleanedOcrText: 'clean restart text',
        averageConfidence: 0.91,
        lowConfidenceCount: 0,
      ),
    );
    await repository.insertNote(
      Note(
        title: 'Restart Note',
        content: 'AI content',
        rawOcrText: 'clean restart text',
        imagePath: '/tmp/processed.jpg',
        tags: const ['restart'],
        summary: 'AI summary',
        sourceType: 'single_image',
        llmStatus: 'success',
        scanSessionId: session.id,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.insertLlmOutput(
      LlmNoteResult(
        sessionId: session.id!,
        taskType: 'organize_note',
        promptVersion: 'prompt-v1',
        modelName: 'mock-llm',
        inputHash: 'restart-hash',
        title: 'Restart AI',
        summary: 'AI summary',
        organizedContent: 'AI content',
        tagsJson: '["restart"]',
        warningsJson: '[]',
        status: 'success',
        createdAt: now,
      ),
    );

    await helper.closeDB();
    helper = DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: dbPath,
    );
    repository = NoteRepository(databaseHelper: helper);

    final reloadedSession = await repository.getScanSessionById(session.id!);
    final reloadedPages = await repository.getScanPagesForSession(session.id!);
    final reloadedOutputs =
        await repository.getLlmOutputsForSession(session.id!);
    final reloadedNotes = await repository.getAllNotes();

    expect(reloadedSession?.status, 'ready_for_proofreading');
    expect(reloadedPages.single.cleanedOcrText, 'clean restart text');
    expect(reloadedOutputs.single.promptVersion, 'prompt-v1');
    expect(reloadedNotes.single.scanSessionId, session.id);
    expect(reloadedNotes.single.llmStatus, 'success');
  });
}
