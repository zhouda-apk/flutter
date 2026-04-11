import '../../../database/database_helper.dart';
import '../../../models/note.dart';
import '../../../services/ocr_service.dart';
import '../../../services/image_service.dart';

class NoteController {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final OcrService _ocr = OcrService();
  final ImageService _imageService = ImageService();

  // ── 取得所有筆記 ──────────────────────────────────────────
  Future<List<Note>> getAllNotes() => _db.getAllNotes();

  // ── 搜尋筆記 ──────────────────────────────────────────────
  Future<List<Note>> searchNotes(String query) {
    if (query.trim().isEmpty) return getAllNotes();
    return _db.searchNotes(query.trim());
  }

  // ── 相機拍攝 → OCR → 回傳草稿 ────────────────────────────
  Future<NoteDraft> captureAndRecognize({
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.1);

    final imagePath = await _imageService.captureFromCamera();
    if (imagePath == null) throw Exception('使用者取消拍攝');

    onProgress?.call(0.4);
    final result = await _ocr.recognizeText(imagePath);
    onProgress?.call(1.0);

    return NoteDraft(
      imagePath: imagePath,
      ocrResult: result,
    );
  }

  // ── 相簿選取（單張） → OCR → 回傳草稿 ────────────────────
  Future<NoteDraft> pickAndRecognize({
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.1);

    final imagePath = await _imageService.pickFromGallery();
    if (imagePath == null) throw Exception('使用者取消選取');

    onProgress?.call(0.4);
    final result = await _ocr.recognizeText(imagePath);
    onProgress?.call(1.0);

    return NoteDraft(imagePath: imagePath, ocrResult: result);
  }

  // ── 相簿多選 → 批次 OCR → 回傳草稿列表 ──────────────────
  Future<List<NoteDraft>> pickMultipleAndRecognize({
    void Function(int current, int total)? onProgress,
  }) async {
    final imagePaths = await _imageService.pickMultipleFromGallery();
    if (imagePaths.isEmpty) return [];

    final results = await _ocr.recognizeMultiple(
      imagePaths,
      onProgress: onProgress,
    );

    return List.generate(
      imagePaths.length,
      (i) => NoteDraft(imagePath: imagePaths[i], ocrResult: results[i]),
    );
  }

  // ── 儲存筆記 ──────────────────────────────────────────────
  Future<Note> saveNote({
    required String title,
    required String content,
    required String rawOcrText,
    required String imagePath,
    required List<String> tags,
  }) async {
    final now = DateTime.now();
    final note = Note(
      title: title.isEmpty ? '未命名筆記' : title,
      content: content,
      rawOcrText: rawOcrText,
      imagePath: imagePath,
      tags: tags,
      createdAt: now,
      updatedAt: now,
    );
    return await _db.insertNote(note);
  }

  // ── 更新筆記 ──────────────────────────────────────────────
  Future<void> updateNote(Note note) => _db.updateNote(note);

  // ── 刪除筆記（連同圖片） ──────────────────────────────────
  Future<void> deleteNote(Note note) async {
    await _db.deleteNote(note.id!);
    await _imageService.deleteImage(note.imagePath);
  }

  void dispose() => _ocr.dispose();
}

// ── OCR 完成後的暫存草稿（尚未寫入 DB） ─────────────────────
class NoteDraft {
  final String imagePath;
  final OcrResult ocrResult;

  NoteDraft({required this.imagePath, required this.ocrResult});

  String get text => ocrResult.fullText;
  bool get needsProofreading => ocrResult.hasLowConfidence;
}
