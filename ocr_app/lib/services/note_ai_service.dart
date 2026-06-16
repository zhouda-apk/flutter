import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/llm_note_result.dart';
import '../models/scan_page.dart';
import '../models/scan_session.dart';
import '../repositories/note_repository.dart';
import 'llm_backend_client.dart';

class NoteAiService {
  final NoteRepository _repository;
  final LlmBackendClient _client;

  NoteAiService({
    NoteRepository? repository,
    LlmBackendClient? client,
  })  : _repository = repository ?? NoteRepository(),
        _client = client ?? LlmBackendClient.fromEnvironment();

  Future<LlmNoteResult> organizeScanSession(
    int sessionId, {
    String language = 'zh-TW',
    Map<String, Object?> options = const {
      'format': 'markdown',
      'generate_tags': true,
    },
  }) async {
    final session = await _repository.getScanSessionById(sessionId);
    if (session == null) {
      throw ArgumentError.value(sessionId, 'sessionId', '掃描任務不存在');
    }

    final pages = await _repository.getScanPagesForSession(sessionId);
    return organizeSession(
      session: session,
      pages: pages,
      language: language,
      options: options,
    );
  }

  Future<LlmNoteResult> organizeText({
    required String text,
    String language = 'zh-TW',
    Map<String, Object?> options = const {
      'format': 'markdown',
      'generate_tags': true,
      'organize_mode': 'general_note',
      'organize_label': '一般筆記',
      'organize_instruction':
          'Organize the content into a clear study or work note.',
    },
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw ArgumentError.value(text, 'text', '沒有可整理的筆記內容');
    }

    final effectiveOptions = {
      ...options,
      'organize_mode': 'general_note',
      'organize_label': '一般筆記',
      'organize_instruction':
          '請將內容整理成繁體中文筆記。保留原文重點，修正明顯錯字，不要自行補充不存在的資訊。輸出需有清楚段落、重點條列與必要的小標題。',
    };

    final request = LlmOrganizeNoteRequest(
      ocrText: trimmedText,
      pages: [
        LlmPageInput(
          pageIndex: 0,
          text: trimmedText,
          summary: _summarizePageText(trimmedText),
        ),
      ],
      language: language,
      options: effectiveOptions,
      clientRequestId: 'note_${DateTime.now().microsecondsSinceEpoch}',
    );
    final inputHash = sha256.convert(utf8.encode(request.ocrText)).toString();
    final result = await _client.organizeNote(request);

    return LlmNoteResult(
      sessionId: 0,
      taskType: request.task,
      promptVersion: result.promptVersion,
      modelName: result.modelName,
      inputHash: inputHash,
      title: result.title,
      summary: result.summary,
      organizedContent: result.organizedContent,
      tagsJson: jsonEncode(result.tags),
      warningsJson: jsonEncode(result.warnings),
      status: 'success',
      createdAt: DateTime.now(),
    );
  }

  Future<LlmNoteResult> organizeSession({
    required ScanSession session,
    required List<ScanPage> pages,
    String language = 'zh-TW',
    Map<String, Object?> options = const {
      'format': 'markdown',
      'generate_tags': true,
    },
  }) async {
    final sessionId = session.id;
    if (sessionId == null) {
      throw ArgumentError.value(session.id, 'session.id', '掃描任務尚未保存');
    }

    final request = _buildRequest(
      sessionId: sessionId,
      pages: pages,
      language: language,
      options: options,
    );
    final inputHash = sha256.convert(utf8.encode(request.ocrText)).toString();

    await _repository.updateScanSession(
      session.copyWith(
        status: 'llm_processing',
        updatedAt: DateTime.now(),
      ),
    );

    try {
      final result = await _client.organizeNote(request);
      final saved = await _repository.insertLlmOutput(
        LlmNoteResult(
          sessionId: sessionId,
          taskType: request.task,
          promptVersion: result.promptVersion,
          modelName: result.modelName,
          inputHash: inputHash,
          title: result.title,
          summary: result.summary,
          organizedContent: result.organizedContent,
          tagsJson: jsonEncode(result.tags),
          warningsJson: jsonEncode(result.warnings),
          status: 'success',
          createdAt: DateTime.now(),
        ),
      );

      await _repository.updateScanSession(
        session.copyWith(
          status: 'ready_for_proofreading',
          updatedAt: DateTime.now(),
        ),
      );
      return saved;
    } on LlmBackendException catch (e) {
      await _saveFailedOutput(
        sessionId: sessionId,
        taskType: request.task,
        inputHash: inputHash,
        errorMessage: e.message,
      );
      await _repository.updateScanSession(
        session.copyWith(
          status: 'ready_for_proofreading',
          updatedAt: DateTime.now(),
        ),
      );
      rethrow;
    }
  }

  LlmOrganizeNoteRequest _buildRequest({
    required int sessionId,
    required List<ScanPage> pages,
    required String language,
    required Map<String, Object?> options,
  }) {
    final sortedPages = pages
        .where((page) => page.cleanedOcrText.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));

    if (sortedPages.isEmpty) {
      throw ArgumentError.value(pages, 'pages', '沒有可整理的 OCR 文字');
    }

    final pageInputs = sortedPages.map((page) {
      final text = page.cleanedOcrText.trim();
      return LlmPageInput(
        pageIndex: page.pageIndex,
        text: text,
        summary: _summarizePageText(text),
        averageConfidence: page.averageConfidence,
        lowConfidenceCount: page.lowConfidenceCount,
      );
    }).toList();

    final combinedText = pageInputs.map((page) {
      return '第 ${page.pageIndex + 1} 頁\n${page.text}';
    }).join('\n\n');

    return LlmOrganizeNoteRequest(
      ocrText: combinedText,
      pages: pageInputs,
      language: language,
      options: options,
      clientRequestId:
          'scan_${sessionId}_${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  String _summarizePageText(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 160) return normalized;
    return '${normalized.substring(0, 160)}...';
  }

  Future<void> _saveFailedOutput({
    required int sessionId,
    required String taskType,
    required String inputHash,
    required String errorMessage,
  }) {
    return _repository.insertLlmOutput(
      LlmNoteResult(
        sessionId: sessionId,
        taskType: taskType,
        promptVersion: 'unknown',
        modelName: 'unknown',
        inputHash: inputHash,
        title: '',
        summary: '',
        organizedContent: '',
        tagsJson: '[]',
        warningsJson: '[]',
        status: 'failed',
        errorMessage: errorMessage,
        createdAt: DateTime.now(),
      ),
    );
  }
}
