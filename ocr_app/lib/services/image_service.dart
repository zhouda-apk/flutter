import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageService {
  final ImagePicker _picker = ImagePicker();

  // ── 開啟相機拍攝 ──────────────────────────────────────────
  Future<String?> captureFromCamera() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (xFile == null) return null;
    return await _saveToAppDirectory(xFile.path);
  }

  // ── 從相簿選取單張 ────────────────────────────────────────
  Future<String?> pickFromGallery() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (xFile == null) return null;
    return await _saveToAppDirectory(xFile.path);
  }

  // ── 從相簿多選（第四頁需求） ──────────────────────────────
  Future<List<String>> pickMultipleFromGallery() async {
    final xFiles = await _picker.pickMultiImage(
      imageQuality: 90,
    );
    if (xFiles.isEmpty) return [];

    final saved = <String>[];
    for (final xFile in xFiles) {
      final path = await _saveToAppDirectory(xFile.path);
      saved.add(path);
    }
    return saved;
  }

  // ── 儲存圖片至 App 私有目錄 ────────────────────────────────
  Future<String> _saveToAppDirectory(String sourcePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDir.path, 'images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}${p.extension(sourcePath)}';
    final destPath = p.join(imagesDir.path, fileName);

    await File(sourcePath).copy(destPath);
    return destPath;
  }

  // ── 刪除圖片檔案 ──────────────────────────────────────────
  Future<void> deleteImage(String imagePath) async {
    final file = File(imagePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
