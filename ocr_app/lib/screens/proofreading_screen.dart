import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/llm_note_result.dart';
import '../models/image_preprocess.dart';
import '../models/scan_page.dart';
import '../models/scan_session.dart';
import '../services/image_crop_service.dart';
import '../services/note_ai_service.dart';
import '../services/ocr_service.dart';
import '../services/scan_pipeline_service.dart';
import '../theme/app_theme.dart';
import 'editor_screen.dart';

typedef NoteAiOrganizer = Future<LlmNoteResult> Function({
  required ScanSession session,
  required List<ScanPage> pages,
  required Map<String, Object?> options,
});

const _baseAiOptions = {
  'format': 'markdown',
  'generate_tags': true,
};

const _aiOrganizeModes = [
  _AiOrganizeMode(
    id: 'general_note',
    label: '一般筆記',
    description: '整理成清楚的標題、摘要與章節',
    instruction: 'Organize the OCR content into a clear study or work note.',
  ),
  _AiOrganizeMode(
    id: 'exam_review',
    label: '考試重點',
    description: '列出名詞、考點與容易混淆處',
    instruction:
        'Organize the content as exam review notes with key terms, likely test points, and confusing concepts.',
  ),
  _AiOrganizeMode(
    id: 'meeting_notes',
    label: '會議紀錄',
    description: '整理決議、討論重點與後續事項',
    instruction:
        'Organize the content as meeting notes with topics, decisions, open questions, and follow-up actions.',
  ),
  _AiOrganizeMode(
    id: 'bullet_summary',
    label: '條列摘要',
    description: '用短句條列整理重點',
    instruction:
        'Summarize the content as concise bullet points grouped by topic.',
  ),
  _AiOrganizeMode(
    id: 'table_summary',
    label: '表格整理',
    description: '盡量用 Markdown 表格比較資訊',
    instruction:
        'Organize comparable information into Markdown tables where appropriate, with short explanations.',
  ),
  _AiOrganizeMode(
    id: 'action_items',
    label: '待辦事項',
    description: '萃取任務、負責項目與期限',
    instruction:
        'Extract action items, tasks, owners if mentioned, deadlines if mentioned, and important reminders.',
  ),
];

const _translationTargets = [
  _TranslationTarget(code: 'en', label: '英文'),
  _TranslationTarget(code: 'ja', label: '日文'),
  _TranslationTarget(code: 'ko', label: '韓文'),
  _TranslationTarget(code: 'zh-CN', label: '簡體中文'),
  _TranslationTarget(code: 'zh-TW', label: '繁體中文'),
];

class ProofreadingScreen extends StatefulWidget {
  final String imagePath;
  final OcrResult ocrResult;
  final List<ScanPageDraft> pages;
  final ScanSession? scanSession;
  final NoteAiOrganizer? aiOrganizer;

  const ProofreadingScreen({
    super.key,
    required this.imagePath,
    required this.ocrResult,
    this.pages = const [],
    this.scanSession,
    this.aiOrganizer,
  });

  @override
  State<ProofreadingScreen> createState() => _ProofreadingScreenState();
}

class _ProofreadingScreenState extends State<ProofreadingScreen> {
  late final List<_ProofreadPage> _pages;
  int _activePage = 0;
  bool _isEditing = false;
  bool _showProcessedImage = true;
  bool _lowConfidenceOnly = false;
  bool _isAiLoading = false;
  bool _isReplacingPage = false;
  int _aiRequestToken = 0;
  final ScanPipelineService _pipeline = ScanPipelineService();
  final ImageCropService _cropService = ImageCropService();
  final ImagePicker _picker = ImagePicker();

  _ProofreadPage get _currentPage => _pages[_activePage];

  @override
  void initState() {
    super.initState();
    _pages = _buildPages();
  }

  List<_ProofreadPage> _buildPages() {
    if (widget.pages.isEmpty) {
      return [
        _ProofreadPage(
          pageIndex: widget.ocrResult.pageIndex ?? 0,
          originalImagePath:
              widget.ocrResult.originalImagePath ?? widget.imagePath,
          processedImagePath:
              widget.ocrResult.processedImagePath ?? widget.imagePath,
          ocrResult: widget.ocrResult,
          scanPage: ScanPage(
            sessionId: widget.scanSession?.id ?? 0,
            pageIndex: widget.ocrResult.pageIndex ?? 0,
            originalImagePath:
                widget.ocrResult.originalImagePath ?? widget.imagePath,
            processedImagePath:
                widget.ocrResult.processedImagePath ?? widget.imagePath,
            preprocessProfile: 'unknown',
            rawOcrText: widget.ocrResult.rawText,
            cleanedOcrText: widget.ocrResult.fullText,
            averageConfidence: widget.ocrResult.averageConfidence,
            lowConfidenceCount: widget.ocrResult.lowConfidenceBlockCount,
          ),
        ),
      ];
    }

    return widget.pages.where((page) => page.ocrResult != null).map((page) {
      final result = page.ocrResult!;
      return _ProofreadPage(
        pageIndex: page.page.pageIndex,
        originalImagePath: page.preprocessResult.originalImagePath,
        processedImagePath: page.preprocessResult.processedImagePath,
        ocrResult: result,
        scanPage: page.page,
      );
    }).toList();
  }

  void _proceedToEditor({
    LlmNoteResult? aiResult,
    bool applyAiContent = false,
  }) {
    final combinedText = _pages
        .map((page) => page.controller.text.trim())
        .where((text) => text.isNotEmpty)
        .join('\n\n');
    final hasAiResult = aiResult != null;
    final editorContent = hasAiResult && applyAiContent
        ? _noteContentFromAi(aiResult)
        : combinedText;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          imagePath: _pages.first.processedImagePath,
          ocrText: editorContent,
          initialTitle: aiResult?.title,
          initialTags: aiResult == null ? const [] : _decodeTags(aiResult),
          initialSummary: hasAiResult && applyAiContent ? aiResult.summary : '',
          sourceType: _pages.length > 1 ? 'multi_page_scan' : 'single_image',
          llmStatus: hasAiResult ? 'success' : 'none',
          scanSessionId: widget.scanSession?.id,
        ),
      ),
    );
  }

  String _noteContentFromAi(LlmNoteResult result) {
    final summary = result.summary.trim();
    final organizedContent = result.organizedContent.trim();

    if (summary.isEmpty) return organizedContent;
    if (organizedContent.isEmpty || organizedContent == summary) {
      return summary;
    }
    return '$summary\n\n$organizedContent';
  }

  Future<void> _showAiOptions() async {
    if (_isAiLoading) {
      _cancelAiOrganize();
      return;
    }

    final options = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => const _AiOptionsSheet(),
    );
    if (options == null) return;
    await _organizeWithAi(options: options);
  }

  Future<void> _organizeWithAi({
    Map<String, Object?> options = _baseAiOptions,
  }) async {
    final session = widget.scanSession;
    if (_isAiLoading) return;
    if (session == null || session.id == null) {
      _showSnackBar('目前沒有可追溯的掃描任務，無法使用 AI 整理');
      return;
    }

    final token = ++_aiRequestToken;
    setState(() => _isAiLoading = true);

    try {
      final organizer = widget.aiOrganizer ??
          ({
            required ScanSession session,
            required List<ScanPage> pages,
            required Map<String, Object?> options,
          }) {
            return NoteAiService().organizeSession(
              session: session,
              pages: pages,
              options: options,
            );
          };
      final result = await organizer(
        session: session,
        pages: _currentScanPages(),
        options: options,
      );
      if (!mounted || token != _aiRequestToken) return;
      setState(() => _isAiLoading = false);
      await _showAiPreview(result);
    } catch (e) {
      if (!mounted || token != _aiRequestToken) return;
      setState(() => _isAiLoading = false);
      _showSnackBar('AI 整理失敗：$e');
    }
  }

  void _cancelAiOrganize() {
    if (!_isAiLoading) return;
    _aiRequestToken++;
    setState(() => _isAiLoading = false);
    _showSnackBar('已取消 AI 整理，校對文字已保留');
  }

  List<ScanPage> _currentScanPages() {
    return _pages.map((page) {
      final text = page.controller.text.trim();
      return page.scanPage.copyWith(
        rawOcrText: text,
        cleanedOcrText: text,
      );
    }).toList();
  }

  Future<void> _showAiPreview(LlmNoteResult result) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (sheetContext) {
        return _AiPreviewSheet(
          result: result,
          onApplyAll: () {
            Navigator.pop(sheetContext);
            _proceedToEditor(aiResult: result, applyAiContent: true);
          },
          onApplyTitleTags: () {
            Navigator.pop(sheetContext);
            _proceedToEditor(aiResult: result);
          },
          onDiscard: () => Navigator.pop(sheetContext),
        );
      },
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  List<String> _decodeTags(LlmNoteResult result) {
    final decoded = jsonDecode(result.tagsJson);
    if (decoded is List) {
      return decoded.map((tag) => tag.toString()).toList();
    }
    return const [];
  }

  Future<void> _showReplaceOptions() {
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('重拍目前頁面'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _replaceCurrentPage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('從相簿替換目前頁面'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _replaceCurrentPage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _replaceCurrentPage(ImageSource source) async {
    final session = widget.scanSession;
    if (_isReplacingPage) return;
    if (session == null || session.id == null) {
      _showSnackBar('目前沒有可追溯的掃描任務，無法替換頁面');
      return;
    }

    final image = await _picker.pickImage(source: source, imageQuality: 95);
    if (image == null) return;
    final imagePath = await _prepareReplacementImage(image.path);
    if (!mounted || imagePath == null) return;

    setState(() => _isReplacingPage = true);
    try {
      final current = _currentPage;
      final replacement = await _pipeline.replacePageImage(
        session: session,
        currentPage: ScanPageDraft(
          page: current.scanPage,
          preprocessResult: ImagePreprocessResult(
            originalImagePath: current.originalImagePath,
            processedImagePath: current.processedImagePath,
            profile: ImagePreprocessProfile.autoDocument,
            wasProcessed: true,
            usedFallback: false,
            metadata: const {},
          ),
          ocrResult: current.ocrResult,
        ),
        imagePath: imagePath,
      );

      if (!mounted) return;
      if (!replacement.isSuccess) {
        setState(() => _isReplacingPage = false);
        _showSnackBar('目前頁面替換後仍無法辨識，請再試一次');
        return;
      }

      current.controller.dispose();
      setState(() {
        _pages[_activePage] = _ProofreadPage(
          pageIndex: replacement.page.pageIndex,
          originalImagePath: replacement.preprocessResult.originalImagePath,
          processedImagePath: replacement.preprocessResult.processedImagePath,
          ocrResult: replacement.ocrResult!,
          scanPage: replacement.page,
        );
        _isEditing = false;
        _lowConfidenceOnly = false;
        _isReplacingPage = false;
      });
      _showSnackBar('第 ${_activePage + 1} 頁已更新');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isReplacingPage = false);
      _showSnackBar('替換失敗：$e');
    }
  }

  Future<String?> _prepareReplacementImage(String imagePath) async {
    final action = await showModalBottomSheet<_ReplacementCropAction>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const ListTile(
              title: Text('替換前處理'),
              subtitle: Text('裁掉非本文區域後再重新辨識'),
            ),
            ListTile(
              leading: const Icon(Icons.crop, color: AppColors.primary),
              title: const Text('裁切後替換'),
              onTap: () => Navigator.pop(context, _ReplacementCropAction.crop),
            ),
            ListTile(
              leading: const Icon(Icons.article_outlined,
                  color: AppColors.textMuted),
              title: const Text('直接替換'),
              onTap: () =>
                  Navigator.pop(context, _ReplacementCropAction.original),
            ),
            ListTile(
              leading: const Icon(Icons.close, color: AppColors.textMuted),
              title: const Text('取消'),
              onTap: () =>
                  Navigator.pop(context, _ReplacementCropAction.cancel),
            ),
          ],
        ),
      ),
    );

    if (action == _ReplacementCropAction.crop) {
      if (!mounted) return null;
      return _cropService.cropForOcr(context, imagePath);
    }
    if (action == _ReplacementCropAction.original) {
      return imagePath;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final lowConfidenceBlocks =
        _currentPage.ocrResult.blocks.where((b) => b.isLowConfidence).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('辨識校對'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _proceedToEditor,
            child: const Text('下一步',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildImageSection(),
          if (_pages.length > 1) _buildPageSelector(),
          _buildDivider(lowConfidenceBlocks.length),
          Expanded(child: _buildTextSection()),
          _buildActionBar(),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    final imagePath = _showProcessedImage
        ? _currentPage.processedImagePath
        : _currentPage.originalImagePath;

    return SizedBox(
      height: 200,
      child: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Image.file(
              File(imagePath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surfaceAlt,
                child: const Center(
                  child: Icon(Icons.image_outlined,
                      size: 48, color: AppColors.textFaint),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: _ImageToggleButton(
              label: _showProcessedImage ? '處理後' : '原圖',
              onTap: () {
                setState(() => _showProcessedImage = !_showProcessedImage);
              },
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '捏合縮放',
                style: TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageSelector() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _pages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, index) {
          final active = index == _activePage;
          return GestureDetector(
            onTap: () => setState(() {
              _activePage = index;
              _isEditing = false;
            }),
            child: Container(
              width: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: active ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                '第 ${index + 1} 頁',
                style: TextStyle(
                  fontSize: 12,
                  color: active ? Colors.white : AppColors.textMuted,
                  fontWeight: active ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDivider(int errorCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppColors.surfaceAlt,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              _pages.length > 1
                  ? '辨識文字 ${_activePage + 1}/${_pages.length}'
                  : '辨識文字',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (errorCount > 0) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$errorCount 處可能錯誤',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Text(
                  '無低信心',
                  style: TextStyle(fontSize: 11, color: AppColors.textFaint),
                ),
              ],
              const SizedBox(width: 8),
              InkWell(
                onTap: errorCount == 0
                    ? null
                    : () => setState(
                          () => _lowConfidenceOnly = !_lowConfidenceOnly,
                        ),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Text(
                    _lowConfidenceOnly ? '顯示全部' : '只看低信心',
                    style: TextStyle(
                      fontSize: 11,
                      color: errorCount == 0
                          ? AppColors.textFaint
                          : AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextSection() {
    return Container(
      color: AppColors.surface,
      child: _isEditing
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _currentPage.controller,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontSize: 14, height: 1.7),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '辨識文字將顯示在此…',
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildHighlightedText(),
            ),
    );
  }

  Widget _buildHighlightedText() {
    if (_currentPage.ocrResult.blocks.isEmpty) {
      return Text(
        _currentPage.controller.text.isEmpty
            ? '（無辨識結果）'
            : _currentPage.controller.text,
        style: const TextStyle(fontSize: 14, height: 1.7),
      );
    }

    final blocks = _lowConfidenceOnly
        ? _currentPage.ocrResult.blocks.where((block) => block.isLowConfidence)
        : _currentPage.ocrResult.blocks;

    if (_lowConfidenceOnly && blocks.isEmpty) {
      return const Text(
        '這一頁目前沒有低信心文字區塊。',
        style: TextStyle(fontSize: 14, height: 1.7, color: AppColors.textMuted),
      );
    }

    return Wrap(
      children: blocks.map((block) {
        final isLow = block.isLowConfidence;
        return GestureDetector(
          onTap: isLow ? () => setState(() => _isEditing = true) : null,
          child: Container(
            decoration: isLow
                ? const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.danger, width: 2),
                    ),
                  )
                : null,
            child: _buildBlockText(block),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBlockText(OcrBlock block) {
    if (block.fragments.isEmpty) {
      return Text(
        block.text,
        style: const TextStyle(
          fontSize: 14,
          height: 1.7,
          color: AppColors.text,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        children: block.fragments.map((fragment) {
          final isLow = fragment.isLowConfidence;
          return TextSpan(
            text: fragment.text,
            style: TextStyle(
              fontSize: 14,
              height: 1.7,
              color: isLow ? AppColors.danger : AppColors.text,
              fontWeight: isLow ? FontWeight.w600 : FontWeight.w400,
              decoration:
                  isLow ? TextDecoration.underline : TextDecoration.none,
              decorationColor: AppColors.danger,
              decorationThickness: 1.5,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isReplacingPage ? null : _showReplaceOptions,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Text(
                    _isReplacingPage ? '替換中' : '重拍/替換',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _isEditing = !_isEditing),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Text(
                    _isEditing ? '預覽模式' : '手動編輯',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isAiLoading ? _cancelAiOrganize : _showAiOptions,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  icon: _isAiLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome, size: 16),
                  label: Text(
                    _isAiLoading ? '取消 AI' : 'AI 整理',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _proceedToEditor(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('確認文字', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final page in _pages) {
      page.controller.dispose();
    }
    _pipeline.dispose();
    super.dispose();
  }
}

enum _ReplacementCropAction { crop, original, cancel }

class _ProofreadPage {
  final int pageIndex;
  final String originalImagePath;
  final String processedImagePath;
  final OcrResult ocrResult;
  final ScanPage scanPage;
  final TextEditingController controller;

  _ProofreadPage({
    required this.pageIndex,
    required this.originalImagePath,
    required this.processedImagePath,
    required this.ocrResult,
    required this.scanPage,
  }) : controller = TextEditingController(text: ocrResult.fullText);
}

class _ImageToggleButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ImageToggleButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  }
}

class _AiOptionsSheet extends StatefulWidget {
  const _AiOptionsSheet();

  @override
  State<_AiOptionsSheet> createState() => _AiOptionsSheetState();
}

const _aiPromptPresets = {
  'general_note': _AiPromptPreset(
    label: '一般筆記',
    description: '整理成清楚、可閱讀的繁體中文筆記。',
    instruction:
        '請將 OCR 內容整理成繁體中文筆記。保留原文重點，修正明顯 OCR 錯字，不要自行補充不存在的資訊。輸出需有清楚段落、重點條列與必要的小標題。',
  ),
  'exam_review': _AiPromptPreset(
    label: '考試複習',
    description: '整理核心觀念、可能考點與容易混淆的內容。',
    instruction:
        '請將 OCR 內容整理成繁體中文考試複習筆記。請列出核心觀念、可能考點、重要名詞、容易混淆的地方，並用條列方式呈現。不要加入原文沒有提到的知識。',
  ),
  'meeting_notes': _AiPromptPreset(
    label: '會議紀錄',
    description: '整理議題、決議、待確認問題與後續行動。',
    instruction:
        '請將 OCR 內容整理成繁體中文會議紀錄。請分成會議主題、討論重點、已決議事項、待確認問題與後續行動。若負責人或期限未出現，請標示為未提及。',
  ),
  'bullet_summary': _AiPromptPreset(
    label: '條列摘要',
    description: '整理成短而清楚的重點條列。',
    instruction: '請將 OCR 內容整理成繁體中文條列摘要。請依主題分組，每點保持精簡，優先保留關鍵資訊、數字、時間、名稱與結論。',
  ),
  'table_summary': _AiPromptPreset(
    label: '表格整理',
    description: '適合比較、分類與欄位資訊。',
    instruction:
        '請將 OCR 內容整理成繁體中文 Markdown 表格。適合比較或分類的資訊請放入表格，表格後補上簡短說明。若內容不適合表格，請改用條列整理。',
  ),
  'action_items': _AiPromptPreset(
    label: '待辦事項',
    description: '萃取任務、期限、負責人與提醒。',
    instruction: '請從 OCR 內容中萃取繁體中文待辦事項。請列出任務、負責人、期限、優先順序與重要提醒。若某欄位未提及，請寫「未提及」。',
  ),
};

const _translationTargetLabels = {
  'en': '英文',
  'ja': '日文',
  'ko': '韓文',
  'zh-CN': '簡體中文',
  'zh-TW': '繁體中文',
};

_AiPromptPreset _promptPresetForMode(_AiOrganizeMode mode) {
  return _aiPromptPresets[mode.id] ??
      _AiPromptPreset(
        label: mode.label,
        description: mode.description,
        instruction: mode.instruction,
      );
}

String _translationLabelForTarget(_TranslationTarget target) {
  return _translationTargetLabels[target.code] ?? target.label;
}

class _AiOptionsSheetState extends State<_AiOptionsSheet> {
  _AiOrganizeMode _selectedMode = _aiOrganizeModes.first;
  bool _translate = false;
  _TranslationTarget _target = _translationTargets.first;

  Map<String, Object?> _buildOptions() {
    final preset = _promptPresetForMode(_selectedMode);
    return {
      ..._baseAiOptions,
      'organize_mode': _selectedMode.id,
      'organize_label': preset.label,
      'organize_instruction': preset.instruction,
      'translate_enabled': _translate,
      if (_translate) 'target_language': _translationLabelForTarget(_target),
      if (_translate) 'target_language_code': _target.code,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'AI 整理方式',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '選擇你希望 OCR 內容被整理成哪種格式。',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _aiOrganizeModes.map((mode) {
                final selected = mode.id == _selectedMode.id;
                final preset = _promptPresetForMode(mode);
                return ChoiceChip(
                  label: Text(preset.label),
                  selected: selected,
                  selectedColor: AppColors.surfaceAlt,
                  labelStyle: TextStyle(
                    color: selected ? AppColors.primary : AppColors.textMuted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                  onSelected: (_) => setState(() => _selectedMode = mode),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _promptPresetForMode(_selectedMode).description,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _translate,
                      onChanged: (value) => setState(() => _translate = value),
                      title: const Text('同時翻譯'),
                      subtitle: const Text('將整理後內容翻譯成指定語言'),
                      activeThumbColor: AppColors.primary,
                    ),
                    if (_translate)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: DropdownButtonFormField<_TranslationTarget>(
                          initialValue: _target,
                          decoration: const InputDecoration(
                            labelText: '目標語言',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _translationTargets.map((target) {
                            return DropdownMenuItem(
                              value: target,
                              child: Text(_translationLabelForTarget(target)),
                            );
                          }).toList(),
                          onChanged: (target) {
                            if (target == null) return;
                            setState(() => _target = target);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, _buildOptions()),
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('開始整理'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AiPreviewSheet extends StatelessWidget {
  final LlmNoteResult result;
  final VoidCallback onApplyAll;
  final VoidCallback onApplyTitleTags;
  final VoidCallback onDiscard;

  const _AiPreviewSheet({
    required this.result,
    required this.onApplyAll,
    required this.onApplyTitleTags,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final tags = _decodeJsonList(result.tagsJson);
    final warnings = _decodeJsonList(result.warningsJson);

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        minChildSize: 0.48,
        maxChildSize: 0.96,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'AI 整理預覽',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: '關閉',
                          onPressed: onDiscard,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const _SectionLabel('建議標題'),
                    Text(
                      result.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const _SectionLabel('摘要'),
                    Text(result.summary, style: const TextStyle(height: 1.6)),
                    const _SectionLabel('整理後內容'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        result.organizedContent,
                        style: const TextStyle(fontSize: 14, height: 1.7),
                      ),
                    ),
                    if (tags.isNotEmpty) ...[
                      const _SectionLabel('標籤'),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tags.map((tag) {
                          return Chip(
                            label: Text(tag),
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],
                    if (warnings.isNotEmpty) ...[
                      const _SectionLabel('提醒'),
                      ...warnings.map(
                        (warning) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 18,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  warning,
                                  style: const TextStyle(
                                    color: Color(0xFF92400E),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Model: ${result.modelName} · Prompt: ${result.promptVersion}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onDiscard,
                            child: const Text('放棄'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onApplyTitleTags,
                            child: const Text('只套用標題/tags'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onApplyAll,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('套用全部'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<String> _decodeJsonList(String jsonText) {
    final decoded = jsonDecode(jsonText);
    if (decoded is List) {
      return decoded.map((item) => item.toString()).toList();
    }
    return const [];
  }
}

class _AiOrganizeMode {
  final String id;
  final String label;
  final String description;
  final String instruction;

  const _AiOrganizeMode({
    required this.id,
    required this.label,
    required this.description,
    required this.instruction,
  });
}

class _AiPromptPreset {
  final String label;
  final String description;
  final String instruction;

  const _AiPromptPreset({
    required this.label,
    required this.description,
    required this.instruction,
  });
}

class _TranslationTarget {
  final String code;
  final String label;

  const _TranslationTarget({
    required this.code,
    required this.label,
  });
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
