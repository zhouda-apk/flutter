import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/llm_note_result.dart';
import '../models/note.dart';
import '../models/ocr_block_record.dart';
import '../models/scan_page.dart';
import '../models/scan_session.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static const int dbVersion = 3;

  final DatabaseFactory? _databaseFactory;
  final String? _databasePath;
  Database? _database;

  DatabaseHelper._init({
    DatabaseFactory? databaseFactory,
    String? databasePath,
  })  : _databaseFactory = databaseFactory,
        _databasePath = databasePath;

  factory DatabaseHelper.forTesting({
    required DatabaseFactory databaseFactory,
    required String databasePath,
  }) {
    return DatabaseHelper._init(
      databaseFactory: databaseFactory,
      databasePath: databasePath,
    );
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ocr_notes.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final path = _databasePath ?? join(await getDatabasesPath(), fileName);
    final options = OpenDatabaseOptions(
      version: dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _ensureSchema(db);
      },
      onOpen: (db) async {
        await _ensureSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _ensureSchema(db);
      },
    );

    final factory = _databaseFactory;
    if (factory != null) {
      return factory.openDatabase(path, options: options);
    }

    return openDatabase(
      path,
      version: options.version,
      onConfigure: options.onConfigure,
      onCreate: options.onCreate,
      onOpen: options.onOpen,
      onUpgrade: options.onUpgrade,
    );
  }

  Future<void> _ensureSchema(Database db) async {
    await _ensureNotesTable(db);
    await _ensureScanSessionsTable(db);
    await _ensureScanPagesTable(db);
    await _ensureOcrBlocksTable(db);
    await _ensureLlmOutputsTable(db);
    await _ensureIndexes(db);
  }

  Future<void> _ensureNotesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notes (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        title           TEXT NOT NULL,
        content         TEXT NOT NULL,
        raw_ocr_text    TEXT NOT NULL,
        image_path      TEXT NOT NULL,
        tags            TEXT NOT NULL DEFAULT '',
        summary         TEXT NOT NULL DEFAULT '',
        source_type     TEXT NOT NULL DEFAULT 'single_image',
        llm_status      TEXT NOT NULL DEFAULT 'none',
        scan_session_id INTEGER,
        created_at      TEXT NOT NULL,
        updated_at      TEXT NOT NULL
      )
    ''');

    final existing = await _columnNames(db, 'notes');

    Future<void> addTextColumn(String name, String defaultValue) async {
      if (existing.contains(name)) return;
      await db.execute(
        "ALTER TABLE notes ADD COLUMN $name TEXT NOT NULL DEFAULT '$defaultValue'",
      );
      existing.add(name);
    }

    Future<void> addNullableIntegerColumn(String name) async {
      if (existing.contains(name)) return;
      await db.execute('ALTER TABLE notes ADD COLUMN $name INTEGER');
      existing.add(name);
    }

    await addTextColumn('raw_ocr_text', '');
    await addTextColumn('image_path', '');
    await addTextColumn('tags', '');
    await addTextColumn('summary', '');
    await addTextColumn('source_type', 'single_image');
    await addTextColumn('llm_status', 'none');
    await addNullableIntegerColumn('scan_session_id');
    await addTextColumn('created_at', '');
    await addTextColumn('updated_at', '');
  }

  Future<void> _ensureScanSessionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scan_sessions (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        status        TEXT NOT NULL,
        source        TEXT NOT NULL,
        page_count    INTEGER NOT NULL DEFAULT 0,
        created_at    TEXT NOT NULL,
        updated_at    TEXT NOT NULL,
        error_message TEXT
      )
    ''');
  }

  Future<void> _ensureScanPagesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scan_pages (
        id                   INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id           INTEGER NOT NULL,
        page_index           INTEGER NOT NULL,
        original_image_path  TEXT NOT NULL,
        processed_image_path TEXT NOT NULL,
        preprocess_profile   TEXT NOT NULL,
        raw_ocr_text         TEXT NOT NULL,
        cleaned_ocr_text     TEXT NOT NULL,
        average_confidence   REAL NOT NULL DEFAULT 0,
        low_confidence_count INTEGER NOT NULL DEFAULT 0,
        metadata_json        TEXT NOT NULL DEFAULT '{}',
        FOREIGN KEY(session_id) REFERENCES scan_sessions(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _ensureOcrBlocksTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ocr_blocks (
        id                 INTEGER PRIMARY KEY AUTOINCREMENT,
        page_id            INTEGER NOT NULL,
        block_index        INTEGER NOT NULL,
        text               TEXT NOT NULL,
        confidence         REAL NOT NULL DEFAULT 0,
        bounding_box_json  TEXT NOT NULL DEFAULT '{}',
        is_low_confidence  INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(page_id) REFERENCES scan_pages(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _ensureLlmOutputsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS llm_outputs (
        id                 INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id         INTEGER NOT NULL,
        note_id            INTEGER,
        task_type          TEXT NOT NULL,
        prompt_version     TEXT NOT NULL,
        model_name         TEXT NOT NULL,
        input_hash         TEXT NOT NULL,
        title              TEXT NOT NULL,
        summary            TEXT NOT NULL,
        organized_content  TEXT NOT NULL,
        tags_json          TEXT NOT NULL DEFAULT '[]',
        warnings_json      TEXT NOT NULL DEFAULT '[]',
        status             TEXT NOT NULL,
        error_message      TEXT,
        created_at         TEXT NOT NULL,
        FOREIGN KEY(session_id) REFERENCES scan_sessions(id) ON DELETE CASCADE,
        FOREIGN KEY(note_id) REFERENCES notes(id) ON DELETE SET NULL
      )
    ''');
  }

  Future<void> _ensureIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notes_scan_session_id ON notes(scan_session_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_scan_pages_session_id ON scan_pages(session_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ocr_blocks_page_id ON ocr_blocks(page_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_llm_outputs_session_id ON llm_outputs(session_id)',
    );
  }

  Future<Set<String>> _columnNames(Database db, String tableName) async {
    final info = await db.rawQuery('PRAGMA table_info($tableName)');
    return {
      for (final row in info) (row['name'] ?? '').toString(),
    };
  }

  Future<Note> insertNote(Note note) async {
    final db = await database;
    final id = await db.insert('notes', note.toMap());
    return note.copyWith(id: id);
  }

  Future<List<Note>> getAllNotes() async {
    final db = await database;
    final maps = await db.query(
      'notes',
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => Note.fromMap(m)).toList();
  }

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

  Future<int> updateNote(Note note) async {
    if (note.id == null) throw Exception('筆記ID不能為空');
    final db = await database;
    return db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<int> deleteNote(int id) async {
    final db = await database;
    return db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<ScanSession> insertScanSession(ScanSession session) async {
    final db = await database;
    final id = await db.insert('scan_sessions', session.toMap());
    return session.copyWith(id: id);
  }

  Future<ScanSession?> getScanSessionById(int id) async {
    final db = await database;
    final maps = await db.query(
      'scan_sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ScanSession.fromMap(maps.first);
  }

  Future<int> updateScanSession(ScanSession session) async {
    if (session.id == null) throw Exception('掃描任務ID不能為空');
    final db = await database;
    return db.update(
      'scan_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<ScanPage> insertScanPage(ScanPage page) async {
    final db = await database;
    final id = await db.insert('scan_pages', page.toMap());
    return page.copyWith(id: id);
  }

  Future<int> updateScanPage(ScanPage page) async {
    if (page.id == null) throw Exception('掃描頁面ID不能為空');
    final db = await database;
    return db.update(
      'scan_pages',
      page.toMap(),
      where: 'id = ?',
      whereArgs: [page.id],
    );
  }

  Future<List<ScanPage>> getScanPagesForSession(int sessionId) async {
    final db = await database;
    final maps = await db.query(
      'scan_pages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'page_index ASC',
    );
    return maps.map((m) => ScanPage.fromMap(m)).toList();
  }

  Future<OcrBlockRecord> insertOcrBlock(OcrBlockRecord block) async {
    final db = await database;
    final id = await db.insert('ocr_blocks', block.toMap());
    return block.copyWith(id: id);
  }

  Future<int> deleteOcrBlocksForPage(int pageId) async {
    final db = await database;
    return db.delete(
      'ocr_blocks',
      where: 'page_id = ?',
      whereArgs: [pageId],
    );
  }

  Future<List<OcrBlockRecord>> getOcrBlocksForPage(int pageId) async {
    final db = await database;
    final maps = await db.query(
      'ocr_blocks',
      where: 'page_id = ?',
      whereArgs: [pageId],
      orderBy: 'block_index ASC',
    );
    return maps.map((m) => OcrBlockRecord.fromMap(m)).toList();
  }

  Future<LlmNoteResult> insertLlmOutput(LlmNoteResult output) async {
    final db = await database;
    final id = await db.insert('llm_outputs', output.toMap());
    return output.copyWith(id: id);
  }

  Future<List<LlmNoteResult>> getLlmOutputsForSession(int sessionId) async {
    final db = await database;
    final maps = await db.query(
      'llm_outputs',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => LlmNoteResult.fromMap(m)).toList();
  }

  Future<void> closeDB() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
