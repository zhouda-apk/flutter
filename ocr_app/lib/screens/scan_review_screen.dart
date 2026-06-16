import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/scan_pipeline_service.dart';
import '../theme/app_theme.dart';
import 'proofreading_screen.dart';

class ScanReviewScreen extends StatefulWidget {
  final ScanPipelineResult scanResult;

  const ScanReviewScreen({
    super.key,
    required this.scanResult,
  });

  @override
  State<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends State<ScanReviewScreen> {
  late List<ScanPageDraft> _pages;
  final ScanPipelineService _pipeline = ScanPipelineService();
  final ImagePicker _picker = ImagePicker();
  int? _replacingIndex;
  String _replaceStatus = '';

  List<ScanPageDraft> get _successfulPages {
    return _pages.where((page) => page.isSuccess).toList();
  }

  @override
  void initState() {
    super.initState();
    _pages = List.of(widget.scanResult.pages);
  }

  @override
  void dispose() {
    _pipeline.dispose();
    super.dispose();
  }

  void _continueToProofreading() {
    final successful = _successfulPages;
    if (successful.isEmpty) {
      _showSnackBar('目前沒有可校對的辨識結果，請先重拍或替換頁面');
      return;
    }

    final first = successful.first;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ProofreadingScreen(
          imagePath: first.preprocessResult.processedImagePath,
          ocrResult: first.ocrResult!,
          pages: successful,
          scanSession: widget.scanResult.session,
        ),
      ),
    );
  }

  Future<void> _showReplaceOptions(int index) {
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
                title: const Text('重拍此頁'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _replacePage(index, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('從相簿替換'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _replacePage(index, ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _replacePage(int index, ImageSource source) async {
    if (_replacingIndex != null) return;

    final image = await _picker.pickImage(source: source, imageQuality: 95);
    if (image == null) return;

    setState(() {
      _replacingIndex = index;
      _replaceStatus = '正在處理第 ${index + 1} 頁';
    });

    try {
      final replacement = await _pipeline.replacePageImage(
        session: widget.scanResult.session,
        currentPage: _pages[index],
        imagePath: image.path,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _replaceStatus = progress.message);
        },
      );
      if (!mounted) return;
      setState(() {
        _pages[index] = replacement;
        _replacingIndex = null;
        _replaceStatus = '';
      });
      if (replacement.isSuccess) {
        _showSnackBar('第 ${index + 1} 頁已更新');
      } else {
        _showSnackBar('第 ${index + 1} 頁仍無法辨識，請再試一次');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _replacingIndex = null;
        _replaceStatus = '';
      });
      _showSnackBar('替換失敗：$e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final successCount = _successfulPages.length;
    final failedCount = _pages.length - successCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('掃描結果總覽'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: successCount > 0 ? _continueToProofreading : null,
            child: const Text(
              '開始校對',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummary(successCount, failedCount),
          if (_replacingIndex != null) _buildReplacingBanner(),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _pages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                return _ScanPageReviewCard(
                  page: _pages[index],
                  pageNumber: index + 1,
                  isReplacing: _replacingIndex == index,
                  onReplace: () => _showReplaceOptions(index),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: ElevatedButton.icon(
            onPressed: successCount > 0 ? _continueToProofreading : null,
            icon: const Icon(Icons.fact_check_outlined, size: 18),
            label: const Text('進入校對'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFE5E7EB),
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(int successCount, int failedCount) {
    final lowConfidenceCount = _successfulPages
        .where((page) => page.ocrResult?.hasLowConfidence ?? false)
        .length;

    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          _SummaryMetric(label: '總頁數', value: '${_pages.length}'),
          _SummaryMetric(label: '成功', value: '$successCount'),
          _SummaryMetric(label: '需確認', value: '$lowConfidenceCount'),
          _SummaryMetric(label: '失敗', value: '$failedCount'),
        ],
      ),
    );
  }

  Widget _buildReplacingBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF7ED),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _replaceStatus,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9A3412)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanPageReviewCard extends StatelessWidget {
  final ScanPageDraft page;
  final int pageNumber;
  final bool isReplacing;
  final VoidCallback onReplace;

  const _ScanPageReviewCard({
    required this.page,
    required this.pageNumber,
    required this.isReplacing,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    final result = page.ocrResult;
    final isSuccess = page.isSuccess;
    final confidence = result?.averageConfidence ?? page.page.averageConfidence;
    final lowCount =
        result?.lowConfidenceBlockCount ?? page.page.lowConfidenceCount;
    final textLength = result?.fullText.trim().length ?? 0;
    final imagePath = page.preprocessResult.processedImagePath;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 72,
              height: 92,
              child: Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.surfaceAlt,
                  child: const Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '第 $pageNumber 頁',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _StatusPill(
                      label: isSuccess ? (lowCount > 0 ? '需確認' : '完成') : '失敗',
                      color: isSuccess
                          ? (lowCount > 0
                              ? AppColors.warning
                              : AppColors.success)
                          : AppColors.danger,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isSuccess
                      ? '信心 ${(confidence * 100).round()}% · $textLength 字 · 低信心 $lowCount 處'
                      : page.errorMessage ?? '此頁無法辨識',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                Text(
                  result?.fullText.trim().isNotEmpty == true
                      ? result!.fullText.trim()
                      : '沒有可預覽的文字',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.textFaint),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: isReplacing ? null : onReplace,
                    icon: const Icon(Icons.autorenew, size: 15),
                    label: Text(isReplacing ? '處理中' : '重拍/替換'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
