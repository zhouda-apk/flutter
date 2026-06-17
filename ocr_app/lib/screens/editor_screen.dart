import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../controllers/note_controller.dart';
import '../models/llm_note_result.dart';
import '../models/note.dart';
import '../services/note_ai_service.dart';
import '../theme/app_theme.dart';

class EditorScreen extends StatefulWidget {
  final String? imagePath;
  final String? ocrText;
  final Note? existingNote;
  final String? initialTitle;
  final List<String> initialTags;
  final String initialSummary;
  final String sourceType;
  final String llmStatus;
  final int? scanSessionId;

  const EditorScreen({
    super.key,
    this.imagePath,
    this.ocrText,
    this.existingNote,
    this.initialTitle,
    this.initialTags = const [],
    this.initialSummary = '',
    this.sourceType = 'single_image',
    this.llmStatus = 'none',
    this.scanSessionId,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final NoteController _controller = NoteController();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  List<String> _tags = [];
  String _summary = '';
  String _llmStatus = 'none';
  bool _isSaving = false;
  bool _isAiLoading = false;

  bool _isBold = false;
  bool _isUnderline = false;
  bool _isItalic = false;

  @override
  void initState() {
    super.initState();
    final note = widget.existingNote;
    _titleController = TextEditingController(
      text: note?.title ?? widget.initialTitle ?? '',
    );
    _contentController = TextEditingController(
      text: note?.content ?? widget.ocrText ?? '',
    );
    _tags = List.from(note?.tags ?? widget.initialTags);
    _summary = note?.summary ?? widget.initialSummary;
    _llmStatus = note?.llmStatus ?? widget.llmStatus;
  }

  Future<void> _save() async {
    if (_isSaving || _isAiLoading) return;
    setState(() => _isSaving = true);

    try {
      // 🔑 添加 30 秒超時保護，防止 ANR
      final operation = widget.existingNote != null
          ? _controller.updateNote(
              widget.existingNote!.copyWith(
                title: _titleController.text,
                content: _contentController.text,
                tags: _tags,
                summary: _summary,
                llmStatus: _llmStatus,
                updatedAt: DateTime.now(),
              ),
            )
          : _controller.saveNote(
              title: _titleController.text,
              content: _contentController.text,
              rawOcrText: widget.ocrText ?? '',
              imagePath: widget.imagePath ?? '',
              tags: _tags,
              summary: _summary,
              sourceType: widget.sourceType,
              llmStatus: _llmStatus,
              scanSessionId: widget.scanSessionId,
            );

      await operation.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('儲存操作超時，請重試');
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('筆記已儲存'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('儲存失敗：$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _organizeWithAi() async {
    if (_isAiLoading || _isSaving) return;

    final text = _contentController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('目前沒有可整理的筆記內容'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isAiLoading = true);

    try {
      final note = widget.existingNote;
      final sessionId = note?.scanSessionId ?? widget.scanSessionId;
      final service = NoteAiService();
      final result = sessionId != null
          ? await service.organizeScanSession(sessionId)
          : await service.organizeText(text: text);

      if (!mounted) return;
      setState(() {
        if (result.title.trim().isNotEmpty) {
          _titleController.text = result.title.trim();
        }
        final aiContent = _noteContentFromAi(result);
        if (aiContent.isNotEmpty) {
          _contentController.text = aiContent;
        }
        _summary = result.summary;
        _llmStatus = 'success';
        final tags = _decodeTags(result.tagsJson);
        if (tags.isNotEmpty) {
          _tags = tags;
        }
        _isAiLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI 整理完成，確認後請儲存筆記'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAiLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI 整理失敗：$e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
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

  List<String> _decodeTags(String tagsJson) {
    try {
      final value = jsonDecode(tagsJson);
      if (value is List) {
        return value
            .map((tag) => tag.toString().trim())
            .where((tag) => tag.isNotEmpty)
            .toList();
      }
    } catch (_) {
      return const [];
    }
    return const [];
  }

  void _addTag() {
    showDialog(
      context: context,
      builder: (_) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('新增標籤'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: '輸入標籤名稱'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消')),
            TextButton(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  setState(() => _tags.add(ctrl.text.trim()));
                }
                Navigator.pop(context);
              },
              child: const Text('新增'),
            ),
          ],
        );
      },
    );
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(widget.existingNote != null ? '編輯筆記' : '新增筆記'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          _isAiLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  tooltip: 'AI 整理',
                  onPressed: _organizeWithAi,
                  icon: const Icon(Icons.auto_awesome_outlined),
                ),
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text('儲存',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w500)),
                ),
        ],
      ),
      body: Column(
        children: [
          _buildTitleInput(),
          _buildTagRow(),
          _buildFormatToolbar(),
          Expanded(child: _buildEditor()),
        ],
      ),
    );
  }

  Widget _buildTitleInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: TextField(
        controller: _titleController,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        decoration: const InputDecoration(
          hintText: '筆記標題…',
          hintStyle: TextStyle(
              color: AppColors.textFaint, fontWeight: FontWeight.w500),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildTagRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text('標籤：',
                style: TextStyle(fontSize: 12, color: AppColors.textFaint)),
            ..._tags.map((tag) => _TagChip(
                  label: tag,
                  onRemove: () => _removeTag(tag),
                )),
            GestureDetector(
              onTap: _addTag,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '+ 新增',
                  style: TextStyle(fontSize: 11, color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          _FmtBtn(
              label: 'B',
              active: _isBold,
              bold: true,
              onTap: () => setState(() => _isBold = !_isBold)),
          _FmtBtn(
              label: 'U',
              active: _isUnderline,
              underline: true,
              onTap: () => setState(() => _isUnderline = !_isUnderline)),
          _FmtBtn(
              label: 'I',
              active: _isItalic,
              italic: true,
              onTap: () => setState(() => _isItalic = !_isItalic)),
          _divider(),
          _FmtBtn(label: '≡', active: false, onTap: () {}),
          _FmtBtn(label: '1.', active: false, onTap: () {}),
          _divider(),
          _FmtBtn(label: 'H1', active: false, onTap: () {}),
          _FmtBtn(label: 'H2', active: false, onTap: () {}),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
        width: 1,
        height: 18,
        color: AppColors.border,
        margin: const EdgeInsets.symmetric(horizontal: 4));
  }

  Widget _buildEditor() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TextField(
        controller: _contentController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: TextStyle(
          fontSize: 15,
          height: 1.8,
          fontWeight: _isBold ? FontWeight.w500 : FontWeight.normal,
          fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
          decoration:
              _isUnderline ? TextDecoration.underline : TextDecoration.none,
        ),
        decoration: const InputDecoration(
          hintText: '開始輸入筆記內容…',
          hintStyle: TextStyle(color: Color(0xFFCCCCCC)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _controller.dispose();
    super.dispose();
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _TagChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.primaryDark)),
          const SizedBox(width: 3),
          GestureDetector(
            onTap: onRemove,
            child:
                const Icon(Icons.close, size: 12, color: AppColors.primaryDark),
          ),
        ],
      ),
    );
  }
}

class _FmtBtn extends StatelessWidget {
  final String label;
  final bool active;
  final bool bold;
  final bool underline;
  final bool italic;
  final VoidCallback onTap;

  const _FmtBtn({
    required this.label,
    required this.active,
    this.bold = false,
    this.underline = false,
    this.italic = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 32,
        height: 28,
        margin: const EdgeInsets.only(right: 2),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border:
              active ? Border.all(color: AppColors.border, width: 0.5) : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              decoration:
                  underline ? TextDecoration.underline : TextDecoration.none,
              color: active ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
