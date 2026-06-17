import '../database/database_helper.dart';
import '../models/llm_note_result.dart';
import '../models/note.dart';
import '../models/ocr_block_record.dart';
import '../models/scan_page.dart';
import '../models/scan_session.dart';

class NoteRepository {
  final DatabaseHelper _db;

  NoteRepository({DatabaseHelper? databaseHelper})
      : _db = databaseHelper ?? DatabaseHelper.instance;

  Future<Note> insertNote(Note note) => _db.insertNote(note);

  Future<List<Note>> getAllNotes() => _db.getAllNotes();

  Future<Note?> getNoteById(int id) => _db.getNoteById(id);

  Future<List<Note>> searchNotes(String query) => _db.searchNotes(query);

  Future<Note> updateNote(Note note) async {
    await _db.updateNote(note);
    return note;
  }

  Future<void> deleteNote(int id) async {
    await _db.deleteNote(id);
  }

  Future<ScanSession> insertScanSession(ScanSession session) {
    return _db.insertScanSession(session);
  }

  Future<ScanSession?> getScanSessionById(int id) {
    return _db.getScanSessionById(id);
  }

  Future<ScanSession> updateScanSession(ScanSession session) async {
    await _db.updateScanSession(session);
    return session;
  }

  Future<ScanPage> insertScanPage(ScanPage page) {
    return _db.insertScanPage(page);
  }

  Future<ScanPage> updateScanPage(ScanPage page) async {
    await _db.updateScanPage(page);
    return page;
  }

  Future<List<ScanPage>> getScanPagesForSession(int sessionId) {
    return _db.getScanPagesForSession(sessionId);
  }

  Future<OcrBlockRecord> insertOcrBlock(OcrBlockRecord block) {
    return _db.insertOcrBlock(block);
  }

  Future<void> deleteOcrBlocksForPage(int pageId) async {
    await _db.deleteOcrBlocksForPage(pageId);
  }

  Future<List<OcrBlockRecord>> getOcrBlocksForPage(int pageId) {
    return _db.getOcrBlocksForPage(pageId);
  }

  Future<LlmNoteResult> insertLlmOutput(LlmNoteResult output) {
    return _db.insertLlmOutput(output);
  }

  Future<List<LlmNoteResult>> getLlmOutputsForSession(int sessionId) {
    return _db.getLlmOutputsForSession(sessionId);
  }
}
