import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/llm_backend_settings.dart';

enum LlmBackendErrorType {
  timeout,
  backend4xx,
  backend5xx,
  invalidResponse,
  cancelled,
  network,
}

class LlmBackendException implements Exception {
  final LlmBackendErrorType type;
  final String message;
  final int? statusCode;
  final Object? cause;

  const LlmBackendException(
    this.type,
    this.message, {
    this.statusCode,
    this.cause,
  });

  bool get isRetryable =>
      type == LlmBackendErrorType.timeout ||
      type == LlmBackendErrorType.backend5xx ||
      type == LlmBackendErrorType.network;

  @override
  String toString() => message;
}

class LlmBackendConfig {
  final Uri? baseUri;
  final bool mockMode;
  final Duration timeout;

  const LlmBackendConfig({
    this.baseUri,
    required this.mockMode,
    this.timeout = const Duration(seconds: 30),
  });

  factory LlmBackendConfig.fromEnvironment({
    Duration timeout = const Duration(
      seconds: LlmBackendSettings.timeoutSeconds,
    ),
  }) {
    const environmentBaseUrl = String.fromEnvironment('LLM_BACKEND_BASE_URL');
    const mockModeValue = String.fromEnvironment('LLM_MOCK_MODE');
    const configuredBaseUrl = LlmBackendSettings.backendBaseUrl;
    final baseUrl = environmentBaseUrl.trim().isNotEmpty
        ? environmentBaseUrl
        : configuredBaseUrl;
    final trimmedBaseUrl = baseUrl.trim();
    final hasBaseUrl = trimmedBaseUrl.isNotEmpty;
    final mockMode = mockModeValue.isEmpty
        ? LlmBackendSettings.mockMode || !hasBaseUrl
        : mockModeValue.toLowerCase() == 'true';

    return LlmBackendConfig(
      baseUri: hasBaseUrl ? Uri.parse(trimmedBaseUrl) : null,
      mockMode: mockMode,
      timeout: timeout,
    );
  }
}

class LlmPageInput {
  final int pageIndex;
  final String text;
  final String summary;
  final double? averageConfidence;
  final int? lowConfidenceCount;

  const LlmPageInput({
    required this.pageIndex,
    required this.text,
    required this.summary,
    this.averageConfidence,
    this.lowConfidenceCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'page_index': pageIndex,
      'page_number': pageIndex + 1,
      'text': text,
      'summary': summary,
      if (averageConfidence != null) 'average_confidence': averageConfidence,
      if (lowConfidenceCount != null)
        'low_confidence_count': lowConfidenceCount,
    };
  }
}

class LlmOrganizeNoteRequest {
  final String ocrText;
  final List<LlmPageInput> pages;
  final String language;
  final String task;
  final Map<String, Object?> options;
  final String clientRequestId;

  const LlmOrganizeNoteRequest({
    required this.ocrText,
    required this.pages,
    this.language = 'zh-TW',
    this.task = 'organize_note',
    this.options = const {
      'format': 'markdown',
      'generate_tags': true,
    },
    required this.clientRequestId,
  });

  Map<String, dynamic> toJson() {
    return {
      'ocr_text': ocrText,
      'pages': pages.map((p) => p.toJson()).toList(),
      'language': language,
      'task': task,
      'options': options,
      'client_request_id': clientRequestId,
    };
  }
}

class LlmOrganizeNoteResult {
  final String title;
  final String summary;
  final String organizedContent;
  final List<String> tags;
  final List<String> warnings;
  final String modelName;
  final String promptVersion;

  const LlmOrganizeNoteResult({
    required this.title,
    required this.summary,
    required this.organizedContent,
    required this.tags,
    required this.warnings,
    required this.modelName,
    required this.promptVersion,
  });

  factory LlmOrganizeNoteResult.fromJson(Map<String, dynamic> json) {
    return LlmOrganizeNoteResult(
      title: _requiredString(json, 'title'),
      summary: _requiredString(json, 'summary'),
      organizedContent: _requiredString(json, 'organized_content'),
      tags: _requiredStringList(json, 'tags'),
      warnings: _optionalStringList(json, 'warnings'),
      modelName: _optionalString(json, 'model_name') ?? 'unknown',
      promptVersion: _requiredString(json, 'prompt_version'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'summary': summary,
      'organized_content': organizedContent,
      'tags': tags,
      'warnings': warnings,
      'model_name': modelName,
      'prompt_version': promptVersion,
    };
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String) return value;
    throw LlmBackendException(
      LlmBackendErrorType.invalidResponse,
      'AI 回應格式錯誤：$key 必須是字串',
    );
  }

  static String? _optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is String) return value;
    throw LlmBackendException(
      LlmBackendErrorType.invalidResponse,
      'AI 回應格式錯誤：$key 必須是字串',
    );
  }

  static List<String> _requiredStringList(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value is List && value.every((item) => item is String)) {
      return value.cast<String>();
    }
    throw LlmBackendException(
      LlmBackendErrorType.invalidResponse,
      'AI 回應格式錯誤：$key 必須是字串陣列',
    );
  }

  static List<String> _optionalStringList(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value == null) return const [];
    if (value is List && value.every((item) => item is String)) {
      return value.cast<String>();
    }
    throw LlmBackendException(
      LlmBackendErrorType.invalidResponse,
      'AI 回應格式錯誤：$key 必須是字串陣列',
    );
  }
}

class LlmBackendClient {
  static const _organizePath = '/v1/notes/organize';

  final Uri? baseUri;
  final bool mockMode;
  final Duration timeout;
  final http.Client _httpClient;

  LlmBackendClient({
    LlmBackendConfig? config,
    Uri? baseUri,
    bool? mockMode,
    Duration? timeout,
    http.Client? httpClient,
  })  : baseUri = baseUri ?? config?.baseUri,
        mockMode = mockMode ?? config?.mockMode ?? true,
        timeout = timeout ?? config?.timeout ?? const Duration(seconds: 30),
        _httpClient = httpClient ?? http.Client();

  factory LlmBackendClient.fromEnvironment({http.Client? httpClient}) {
    return LlmBackendClient(
      config: LlmBackendConfig.fromEnvironment(),
      httpClient: httpClient,
    );
  }

  Future<LlmOrganizeNoteResult> organizeNote(
    LlmOrganizeNoteRequest request,
  ) async {
    if (mockMode) {
      return _mockOrganizeNote(request);
    }

    final uri = _organizeUri();
    final body = jsonEncode(request.toJson());

    try {
      final response = await _httpClient
          .post(
            uri,
            headers: const {
              'accept': 'application/json',
              'content-type': 'application/json',
            },
            body: body,
          )
          .timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _decodeSuccessResponse(utf8.decode(response.bodyBytes));
      }

      throw _classifyHttpError(response.statusCode);
    } on TimeoutException catch (e) {
      throw LlmBackendException(
        LlmBackendErrorType.timeout,
        'LLM 後端逾時，請稍後重試',
        cause: e,
      );
    } on LlmBackendException {
      rethrow;
    } on http.ClientException catch (e) {
      throw LlmBackendException(
        LlmBackendErrorType.network,
        '無法連線到 LLM 後端，請確認網路狀態',
        cause: e,
      );
    } on FormatException catch (e) {
      throw LlmBackendException(
        LlmBackendErrorType.invalidResponse,
        'AI 回應格式錯誤',
        cause: e,
      );
    }
  }

  void close() {
    _httpClient.close();
  }

  Uri _organizeUri() {
    final uri = baseUri;
    if (uri == null) {
      throw const LlmBackendException(
        LlmBackendErrorType.invalidResponse,
        '尚未設定 LLM 後端位址',
      );
    }

    final basePath = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    return uri.replace(path: '$basePath$_organizePath');
  }

  LlmOrganizeNoteResult _decodeSuccessResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const LlmBackendException(
        LlmBackendErrorType.invalidResponse,
        'AI 回應格式錯誤：最外層必須是物件',
      );
    }
    return LlmOrganizeNoteResult.fromJson(decoded);
  }

  LlmBackendException _classifyHttpError(int statusCode) {
    if (statusCode >= 400 && statusCode < 500) {
      return LlmBackendException(
        LlmBackendErrorType.backend4xx,
        'LLM 後端拒絕請求 (HTTP $statusCode)',
        statusCode: statusCode,
      );
    }
    if (statusCode >= 500 && statusCode < 600) {
      return LlmBackendException(
        LlmBackendErrorType.backend5xx,
        'LLM 後端暫時無法使用 (HTTP $statusCode)',
        statusCode: statusCode,
      );
    }
    return LlmBackendException(
      LlmBackendErrorType.invalidResponse,
      'LLM 後端回應狀態異常 (HTTP $statusCode)',
      statusCode: statusCode,
    );
  }

  LlmOrganizeNoteResult _mockOrganizeNote(LlmOrganizeNoteRequest request) {
    final cleanText = request.ocrText.trim();
    final firstLine = cleanText
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '掃描筆記');
    final title =
        firstLine.length > 18 ? firstLine.substring(0, 18) : firstLine;
    final summary =
        cleanText.length > 80 ? '${cleanText.substring(0, 80)}...' : cleanText;
    final pageSections = request.pages.map((page) {
      return '## 第 ${page.pageIndex + 1} 頁\n\n${page.text.trim()}';
    }).join('\n\n');
    final warningCount = request.pages.fold<int>(
      0,
      (sum, page) => sum + (page.lowConfidenceCount ?? 0),
    );

    return LlmOrganizeNoteResult(
      title: title.isEmpty ? '掃描筆記' : title,
      summary: summary.isEmpty ? '目前沒有可整理的 OCR 文字。' : summary,
      organizedContent: pageSections.isEmpty ? cleanText : pageSections,
      tags: const ['OCR', 'AI整理'],
      warnings: warningCount > 0
          ? ['共有 $warningCount 個 OCR 區塊信心較低，建議人工確認。']
          : const [],
      modelName: 'mock-llm',
      promptVersion: 'mock-v1',
    );
  }
}
