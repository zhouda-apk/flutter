import 'dart:io';

import 'package:flutter/material.dart';
import '../services/ocr_service.dart';
import 'proofreading_screen.dart';

class LoadingScreen extends StatefulWidget {
  final String imagePath;

  const LoadingScreen({super.key, required this.imagePath});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  double _progress = 0.0;
  String _statusText = '正在分析圖片…';
  final OcrService _ocr = OcrService();

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _startOcr();
  }

  Future<void> _startOcr() async {
    _updateProgress(0.2, '正在偵測文字區域…');
    await Future.delayed(const Duration(milliseconds: 400));

    _updateProgress(0.5, '辨識文字內容中…');

    try {
      final result = await _ocr.recognizeText(widget.imagePath);

      _updateProgress(0.85, '整理辨識結果…');
      await Future.delayed(const Duration(milliseconds: 300));

      _updateProgress(1.0, '辨識完成！');
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProofreadingScreen(
            imagePath: widget.imagePath,
            ocrResult: result,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog(e.toString());
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    _ocr.dispose();
    super.dispose();
  }

  void _updateProgress(double value, String text) {
    if (!mounted) return;
    setState(() {
      _progress = value;
      _statusText = text;
    });
  }

  Future<void> _showErrorDialog(String error) async {
    _ocr.dispose();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('辨識失敗'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('重新拍攝'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('辨識中'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildImagePreview(),
            const SizedBox(height: 40),
            _buildSpinner(),
            const SizedBox(height: 24),
            const Text(
              'OCR 辨識處理中',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              _statusText,
              style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildProgressBar(),
            const SizedBox(height: 8),
            Text(
              '預估剩餘時間：約 ${_estimateSeconds()} 秒',
              style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                '取消並重新拍攝',
                style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      width: 160,
      height: 110,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F4F0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(widget.imagePath),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(
            child:
                Icon(Icons.image_outlined, size: 40, color: Color(0xFFDDDDDD)),
          ),
        ),
      ),
    );
  }

  Widget _buildSpinner() {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: _progress,
            strokeWidth: 4,
            backgroundColor: Colors.grey.shade200,
            color: const Color(0xFF6C63FF),
          ),
          Text(
            '${(_progress * 100).toInt()}%',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6C63FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: _progress,
        minHeight: 6,
        backgroundColor: Colors.grey.shade200,
        color: const Color(0xFF6C63FF),
      ),
    );
  }

  int _estimateSeconds() {
    if (_progress >= 0.9) return 1;
    if (_progress >= 0.5) return 2;
    return 3;
  }
}
