import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../../models/note.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ocr_notes.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        title    TEXT NOT NULL,
        content  TEXT NOT NULL,
        raw_ocr_text TEXT NOT NULL,
        image_path   TEXT NOT NULL,
        tags         TEXT NOT NULL DEFAULT '',
        created_at   TEXT NOT NULL,
        updated_at   TEXT NOT NULL
      )
    ''');
  }

  // ── Create ──────────────────────────────────────────────
  Future<Note> insertNote(Note note) async {
    final db = await database;
    final id = await db.insert('notes', note.toMap());
    return note.copyWith(id: id);
  }

  // ── Read all ─────────────────────────────────────────────
  Future<List<Note>> getAllNotes() async {
    final db = await database;
    final maps = await db.query(
      'notes',
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  // ── Read one ─────────────────────────────────────────────
  Future<Note?> getNoteById(int id) async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Note.fromMap(maps.first);
  }

  // ── Search ───────────────────────────────────────────────
  Future<List<Note>> searchNotes(String query) async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'title LIKE ? OR content LIKE ? OR tags LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  // ── Update ───────────────────────────────────────────────
  Future<int> updateNote(Note note) async {
    final db = await database;
    return await db.update(
      'notes',
      note.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  // ── Delete ───────────────────────────────────────────────
  Future<int> deleteNote(int id) async {
    final db = await database;
    return await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> closeDB() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
