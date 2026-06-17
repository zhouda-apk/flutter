import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/image_crop_service.dart';
import '../theme/app_theme.dart';
import 'loading_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _flashOn = false;
  bool _isCapturing = false;
  final ImageCropService _cropService = ImageCropService();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      _cameraController = CameraController(
        _cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('相機初始化失敗：$e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    _flashOn = !_flashOn;
    await _cameraController?.setFlashMode(
      _flashOn ? FlashMode.torch : FlashMode.off,
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _capture() async {
    if (_isCapturing || _cameraController == null) return;
    setState(() => _isCapturing = true);

    try {
      final xFile = await _cameraController!.takePicture();
      if (!mounted) return;

      final imagePath = await _prepareImageForOcr(xFile.path);
      if (!mounted) return;
      if (imagePath == null) {
        setState(() => _isCapturing = false);
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoadingScreen(imagePath: imagePath),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCapturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('拍攝失敗：$e')),
      );
    }
  }

  Future<String?> _prepareImageForOcr(String imagePath) async {
    final action = await showModalBottomSheet<_CaptureAction>(
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
              title: Text('辨識前處理'),
              subtitle: Text('裁掉旁邊頁面、頁腳或手寫區，可提升 OCR 順序與準確度'),
            ),
            ListTile(
              leading: const Icon(Icons.crop, color: AppColors.primary),
              title: const Text('裁切後辨識'),
              onTap: () => Navigator.pop(context, _CaptureAction.crop),
            ),
            ListTile(
              leading: const Icon(Icons.article_outlined,
                  color: AppColors.textMuted),
              title: const Text('直接辨識整張照片'),
              onTap: () => Navigator.pop(context, _CaptureAction.original),
            ),
            ListTile(
              leading: const Icon(Icons.close, color: AppColors.textMuted),
              title: const Text('取消'),
              onTap: () => Navigator.pop(context, _CaptureAction.cancel),
            ),
          ],
        ),
      ),
    );

    if (action == _CaptureAction.crop) {
      if (!mounted) return null;
      return _cropService.cropForOcr(context, imagePath);
    }
    if (action == _CaptureAction.original) {
      return imagePath;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Stack(
        children: [
          if (_isInitialized)
            Positioned.fill(child: CameraPreview(_cameraController!))
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          _buildGridOverlay(),
          _buildTopBar(),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildGridOverlay() {
    return const Positioned.fill(
      child: CustomPaint(painter: _GridPainter()),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
              const Text(
                '拍攝整張文件',
                style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 13),
              ),
              GestureDetector(
                onTap: _toggleFlash,
                child: Icon(
                  _flashOn ? Icons.flash_on : Icons.flash_off,
                  color: _flashOn ? AppColors.accent : Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: const Color(0xFF111827),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16,
          top: 16,
          left: 32,
          right: 32,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: _toggleFlash,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x26FFFFFF),
                ),
                child: Icon(
                  _flashOn ? Icons.flash_on : Icons.flash_auto,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            GestureDetector(
              onTap: _isCapturing ? null : _capture,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: _isCapturing ? 40 : 56,
                    height: _isCapturing ? 40 : 56,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AlbumRedirectHelper()),
                );
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x26FFFFFF),
                  border: Border.all(color: Colors.white30, width: 0.5),
                ),
                child: const Icon(Icons.photo_library_outlined,
                    color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 輔助元件 ─────────────────────────────────────────────

class AlbumRedirectHelper extends StatelessWidget {
  const AlbumRedirectHelper({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const _AlbumImport()),
      );
    });
    return const SizedBox.shrink();
  }
}

enum _CaptureAction { crop, original, cancel }

class _AlbumImport extends StatelessWidget {
  const _AlbumImport();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x1AFFFFFF)
      ..strokeWidth = 0.5;

    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(size.width / 3 * i, 0),
        Offset(size.width / 3 * i, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(0, size.height / 3 * i),
        Offset(size.width, size.height / 3 * i),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
