import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/note_controller.dart';
import '../models/note.dart';

class EditorScreen extends StatefulWidget {
  final String? imagePath;
  final String? ocrText;
  final Note? existingNote;

  const EditorScreen({
    super.key,
    this.imagePath,
    this.ocrText,
    this.existingNote,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final NoteController _controller = NoteController();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  List<String> _tags = [];
  bool _isSaving = false;

  bool _isBold = false;
  bool _isUnderline = false;
  bool _isItalic = false;

  @override
  void initState() {
    super.initState();
    final note = widget.existingNote;
    _titleController = TextEditingController(text: note?.title ?? '');
    _contentController = TextEditingController(
      text: note?.content ?? widget.ocrText ?? '',
    );
    _tags = List.from(note?.tags ?? []);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // 🔑 添加 30 秒超時保護，防止 ANR
      final operation = widget.existingNote != null
          ? _controller.updateNote(
              widget.existingNote!.copyWith(
                title: _titleController.text,
                content: _contentController.text,
                tags: _tags,
                updatedAt: DateTime.now(),
              ),
            )
          : _controller.saveNote(
              title: _titleController.text,
              content: _contentController.text,
              rawOcrText: widget.ocrText ?? '',
              imagePath: widget.imagePath ?? '',
              tags: _tags,
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
          backgroundColor: Color(0xFF6C63FF),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.existingNote != null ? '編輯筆記' : '新增筆記'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
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
        border:
            Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
      ),
      child: TextField(
        controller: _titleController,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        decoration: const InputDecoration(
          hintText: '筆記標題…',
          hintStyle:
              TextStyle(color: Color(0xFFAAAAAA), fontWeight: FontWeight.w500),
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
        border:
            Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text('標籤：',
                style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA))),
            ..._tags.map((tag) => _TagChip(
                  label: tag,
                  onRemove: () => _removeTag(tag),
                )),
            GestureDetector(
              onTap: _addTag,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  border:
                      Border.all(color: const Color(0xFF6C63FF), width: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '+ 新增',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6C63FF)),
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
        color: Color(0xFFF9F8FF),
        border:
            Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
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
        color: const Color(0xFFEEEEEE),
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
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF5B21B6))),
          const SizedBox(width: 3),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 12, color: Color(0xFF5B21B6)),
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
          border: active
              ? Border.all(color: const Color(0xFFDDDDDD), width: 0.5)
              : null,
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
              color: active ? const Color(0xFF6C63FF) : const Color(0xFF888888),
            ),
          ),
        ),
      ),
    );
  }
}
