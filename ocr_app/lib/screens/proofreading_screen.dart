import 'dart:io';
import 'package:flutter/material.dart';
import '../services/ocr_service.dart';
import 'editor_screen.dart';

class ProofreadingScreen extends StatefulWidget {
  final String imagePath;
  final OcrResult ocrResult;

  const ProofreadingScreen({
    super.key,
    required this.imagePath,
    required this.ocrResult,
  });

  @override
  State<ProofreadingScreen> createState() => _ProofreadingScreenState();
}

class _ProofreadingScreenState extends State<ProofreadingScreen> {
  late TextEditingController _textController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.ocrResult.fullText);
  }

  void _proceedToEditor() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          imagePath: widget.imagePath,
          ocrText: _textController.text,
        ),
      ),
    );
  }

  Future<void> _reRecognize() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('重新辨識'),
        content: const Text('重新辨識將覆蓋目前的文字內容，確定嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('確定')),
        ],
      ),
    );
    if (confirm != true) return;

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final lowConfidenceBlocks = widget.ocrResult.blocks
        .where((b) => b.isLowConfidence)
        .toList();

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
            child: const Text('下一步', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildImageSection(),
          _buildDivider(lowConfidenceBlocks.length),
          Expanded(child: _buildTextSection()),
          _buildActionBar(),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return SizedBox(
      height: 200,
      child: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Image.file(
              File(widget.imagePath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFE8E4F0),
                child: const Center(
                  child: Icon(Icons.image_outlined, size: 48, color: Color(0xFFAAAAAA)),
                ),
              ),
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

  Widget _buildDivider(int errorCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: const Color(0xFFF9F8FF),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '辨識文字',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF888888), letterSpacing: 0.5),
          ),
          if (errorCount > 0)
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFCA5A5),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '偵測到 $errorCount 處可能錯誤',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTextSection() {
    return Container(
      color: Colors.white,
      child: _isEditing
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _textController,
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
    if (widget.ocrResult.blocks.isEmpty) {
      return Text(
        _textController.text.isEmpty ? '（無辨識結果）' : _textController.text,
        style: const TextStyle(fontSize: 14, height: 1.7),
      );
    }

    return Wrap(
      children: widget.ocrResult.blocks.map((block) {
        final isLow = block.isLowConfidence;
        return GestureDetector(
          onTap: isLow ? () => setState(() => _isEditing = true) : null,
          child: Container(
            decoration: isLow
                ? const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFEF4444), width: 2),
                    ),
                  )
                : null,
            child: Text(
              block.text,
              style: TextStyle(
                fontSize: 14,
                height: 1.7,
                color: isLow ? const Color(0xFFEF4444) : const Color(0xFF1A1A1A),
              ),
            ),
          ),
        );
      }).toList(),
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
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _reRecognize,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF555555),
                side: const BorderSide(color: Color(0xFFDDDDDD)),
              ),
              child: const Text('重新辨識', style: TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _isEditing = !_isEditing),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF555555),
                side: const BorderSide(color: Color(0xFFDDDDDD)),
              ),
              child: Text(_isEditing ? '預覽模式' : '手動編輯', style: const TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: _proceedToEditor,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
              ),
              child: const Text('確認文字', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
