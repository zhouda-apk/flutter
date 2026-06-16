import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
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

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoadingScreen(imagePath: xFile.path),
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
