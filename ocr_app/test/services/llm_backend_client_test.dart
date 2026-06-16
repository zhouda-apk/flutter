import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ocr_notes_app/services/llm_backend_client.dart';

void main() {
  const request = LlmOrganizeNoteRequest(
    ocrText: '第一頁 OCR 內容',
    pages: [
      LlmPageInput(
        pageIndex: 0,
        text: '第一頁 OCR 內容',
        summary: '第一頁 OCR 內容',
      ),
    ],
    clientRequestId: 'test-request-1',
  );

  test('mock mode returns usable fake data without backend base URL', () async {
    final client = LlmBackendClient(mockMode: true);

    final result = await client.organizeNote(request);

    expect(result.title, isNotEmpty);
    expect(result.summary, contains('第一頁 OCR 內容'));
    expect(result.organizedContent, contains('第 1 頁'));
    expect(result.tags, contains('OCR'));
    expect(result.modelName, 'mock-llm');
  });

  test('successful backend response is validated and parsed', () async {
    late http.Request capturedRequest;
    final client = LlmBackendClient(
      baseUri: Uri.parse('https://backend.example.com/api'),
      mockMode: false,
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'title': '整理標題',
            'summary': '整理摘要',
            'organized_content': '整理後內容',
            'tags': ['課堂', 'OCR'],
            'warnings': ['請確認日期'],
            'model_name': 'test-model',
            'prompt_version': 'v1',
          })),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await client.organizeNote(request);

    expect(capturedRequest.url.path, '/api/v1/notes/organize');
    expect(capturedRequest.headers['content-type'], 'application/json');
    expect(jsonDecode(capturedRequest.body),
        containsPair('ocr_text', request.ocrText));
    expect(result.title, '整理標題');
    expect(result.tags, ['課堂', 'OCR']);
    expect(result.warnings, ['請確認日期']);
  });

  test('timeout is classified', () async {
    final client = LlmBackendClient(
      baseUri: Uri.parse('https://backend.example.com'),
      mockMode: false,
      timeout: const Duration(milliseconds: 5),
      httpClient: MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      client.organizeNote(request),
      throwsA(
        isA<LlmBackendException>().having(
          (e) => e.type,
          'type',
          LlmBackendErrorType.timeout,
        ),
      ),
    );
  });

  test('4xx backend response is classified', () async {
    final client = LlmBackendClient(
      baseUri: Uri.parse('https://backend.example.com'),
      mockMode: false,
      httpClient: MockClient((request) async {
        return http.Response('provider stack should not be exposed', 400);
      }),
    );

    await expectLater(
      client.organizeNote(request),
      throwsA(
        isA<LlmBackendException>()
            .having((e) => e.type, 'type', LlmBackendErrorType.backend4xx)
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.message, 'message', isNot(contains('provider'))),
      ),
    );
  });

  test('5xx backend response is classified as retryable', () async {
    final client = LlmBackendClient(
      baseUri: Uri.parse('https://backend.example.com'),
      mockMode: false,
      httpClient: MockClient((request) async {
        return http.Response('temporary failure', 503);
      }),
    );

    await expectLater(
      client.organizeNote(request),
      throwsA(
        isA<LlmBackendException>()
            .having((e) => e.type, 'type', LlmBackendErrorType.backend5xx)
            .having((e) => e.statusCode, 'statusCode', 503)
            .having((e) => e.isRetryable, 'isRetryable', isTrue),
      ),
    );
  });

  test('invalid response shape is rejected', () async {
    final client = LlmBackendClient(
      baseUri: Uri.parse('https://backend.example.com'),
      mockMode: false,
      httpClient: MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'title': '整理標題',
            'summary': '整理摘要',
            'tags': ['OCR'],
            'prompt_version': 'v1',
          })),
          200,
        );
      }),
    );

    await expectLater(
      client.organizeNote(request),
      throwsA(
        isA<LlmBackendException>().having(
          (e) => e.type,
          'type',
          LlmBackendErrorType.invalidResponse,
        ),
      ),
    );
  });
}
