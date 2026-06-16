import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'loading_screen.dart';
import '../theme/app_theme.dart';

class AlbumPickerScreen extends StatefulWidget {
  const AlbumPickerScreen({super.key});

  @override
  State<AlbumPickerScreen> createState() => _AlbumPickerScreenState();
}

class _AlbumPickerScreenState extends State<AlbumPickerScreen> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _allImages = [];
  final Set<int> _selectedIndices = {};
  int _activeTab = 0;
  bool _isLoading = true;

  final List<String> _tabs = ['最近項目', '文件', '截圖'];

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() => _isLoading = false);
  }

  Future<void> _pickFromGallery() async {
    final files = await _picker.pickMultiImage(imageQuality: 90);
    if (files.isEmpty) return;
    setState(() {
      _allImages = files;
      _selectedIndices.clear();
    });
  }

  void _toggleSelect(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIndices.length == _allImages.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices.addAll(
          List.generate(_allImages.length, (i) => i),
        );
      }
    });
  }

  Future<void> _importSelected() async {
    if (_selectedIndices.isEmpty) return;

    final selected = _selectedIndices.toList()..sort();
    final selectedPaths = selected.map((i) => _allImages[i].path).toList();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => selectedPaths.length == 1
            ? LoadingScreen(imagePath: selectedPaths.first, source: 'gallery')
            : LoadingScreen.multiple(imagePaths: selectedPaths),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('選取照片'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _allImages.isNotEmpty ? _selectAll : null,
            child: Text(
              _selectedIndices.length == _allImages.length &&
                      _allImages.isNotEmpty
                  ? '取消全選'
                  : '全選',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabs(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _allImages.isEmpty
                    ? _buildEmptyState()
                    : _buildGrid(),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: const BoxDecoration(
        border:
            Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final active = _activeTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _tabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w500 : FontWeight.normal,
                    color: active ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(1.5),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1.5,
        mainAxisSpacing: 1.5,
      ),
      itemCount: _allImages.length,
      itemBuilder: (_, i) {
        final selected = _selectedIndices.contains(i);
        return GestureDetector(
          onTap: () => _toggleSelect(i),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(_allImages[i].path), fit: BoxFit.cover),
              if (selected)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                ),
              Positioned(
                top: 6,
                right: 6,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.primary : Colors.black38,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 13, color: Colors.white)
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('尚無圖片',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _pickFromGallery,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('從相簿選取'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final hasSelection = _selectedIndices.isNotEmpty;
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            hasSelection ? '已選 ${_selectedIndices.length} 張' : '點擊圖片選取',
            style: TextStyle(
              fontSize: 13,
              color: hasSelection ? AppColors.primary : AppColors.textFaint,
            ),
          ),
          Row(
            children: [
              if (_allImages.isEmpty)
                OutlinedButton(
                  onPressed: _pickFromGallery,
                  child: const Text('開啟相簿'),
                )
              else
                const SizedBox.shrink(),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: hasSelection ? _importSelected : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                ),
                child: const Text('匯入辨識'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
