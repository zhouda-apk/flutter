import 'dart:io';

import 'package:flutter/material.dart';
import '../services/scan_pipeline_service.dart';
import '../theme/app_theme.dart';
import 'scan_review_screen.dart';

typedef LoadingPipelineRunner = Future<ScanPipelineResult> Function(
  List<String> imagePaths, {
  required String source,
  required void Function(ScanPipelineProgress progress) onProgress,
});

class LoadingScreen extends StatefulWidget {
  final List<String> imagePaths;
  final String source;
  final LoadingPipelineRunner? pipelineRunner;

  LoadingScreen({
    super.key,
    required String imagePath,
    this.source = 'camera',
    this.pipelineRunner,
  }) : imagePaths = [imagePath];

  LoadingScreen.multiple({
    super.key,
    required List<String> imagePaths,
    this.source = 'gallery',
    this.pipelineRunner,
  })  : assert(imagePaths.isNotEmpty),
        imagePaths = List.unmodifiable(imagePaths);

  String get previewImagePath => imagePaths.first;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  double _progress = 0.0;
  String _statusText = '正在分析圖片…';
  final ScanPipelineService _pipeline = ScanPipelineService();

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
    try {
      final pipelineResult = await _runPipeline();

      _updateProgress(0.85, '整理辨識結果…');
      await Future.delayed(const Duration(milliseconds: 300));

      _updateProgress(1.0, '辨識完成！');
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ScanReviewScreen(scanResult: pipelineResult),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog(e.toString());
    }
  }

  Future<ScanPipelineResult> _runPipeline() {
    final runner = widget.pipelineRunner;
    if (runner != null) {
      return runner(
        widget.imagePaths,
        source: widget.source,
        onProgress: (progress) {
          _updateProgress(progress.progress, progress.message);
        },
      );
    }

    if (widget.imagePaths.length > 1) {
      return _pipeline.processImages(
        widget.imagePaths,
        source: widget.source,
        onProgress: (progress) {
          _updateProgress(progress.progress, progress.message);
        },
      );
    }

    return _pipeline.processSingleImage(
      widget.previewImagePath,
      source: widget.source,
      onProgress: (progress) {
        _updateProgress(progress.progress, progress.message);
      },
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    _pipeline.dispose();
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
      backgroundColor: AppColors.background,
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
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildProgressBar(),
            const SizedBox(height: 8),
            Text(
              '預估剩餘時間：約 ${_estimateSeconds()} 秒',
              style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                '取消並重新拍攝',
                style: TextStyle(color: AppColors.textFaint, fontSize: 13),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(widget.previewImagePath),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.image_outlined,
                size: 40, color: AppColors.textFaint),
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
            backgroundColor: AppColors.border,
            color: AppColors.primary,
          ),
          Text(
            '${(_progress * 100).toInt()}%',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
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
        backgroundColor: AppColors.border,
        color: AppColors.primary,
      ),
    );
  }

  int _estimateSeconds() {
    if (_progress >= 0.9) return 1;
    if (_progress >= 0.5) return 2;
    return 3;
  }
}
