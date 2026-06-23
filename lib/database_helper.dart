import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'note.dart';
import 'folder.dart';

// Singleton zarzadzajacy baza danych SQLite
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('notatki.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // Tworzenie bazy od zera (nowa instalacja)
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        reminderAt INTEGER,
        colorIndex INTEGER NOT NULL DEFAULT 0,
        pinned INTEGER NOT NULL DEFAULT 0,
        folderId INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');
  }

  // Migracja istniejacej bazy (zachowuje stare notatki)
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Dodajemy nowe kolumny do tabeli notes
      await db.execute(
          'ALTER TABLE notes ADD COLUMN colorIndex INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE notes ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE notes ADD COLUMN folderId INTEGER');
      // Tworzymy tabele folderow
      await db.execute('''
        CREATE TABLE folders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          createdAt INTEGER NOT NULL
        )
      ''');
    }
  }

  // ---------- NOTATKI ----------

  Future<int> insertNote(Note note) async {
    final db = await instance.database;
    return await db.insert('notes', note.toMap());
  }

  Future<int> updateNote(Note note) async {
    final db = await instance.database;
    return await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<int> deleteNote(int id) async {
    final db = await instance.database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // Pobranie notatek; opcjonalnie filtrowane po folderze.
  // Przypiete na gorze, potem wg daty utworzenia.
  Future<List<Note>> getNotes({int? folderId, bool noFolder = false}) async {
    final db = await instance.database;
    String? where;
    List<Object?>? whereArgs;
    if (noFolder) {
      where = 'folderId IS NULL';
    } else if (folderId != null) {
      where = 'folderId = ?';
      whereArgs = [folderId];
    }
    final result = await db.query(
      'notes',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'pinned DESC, createdAt DESC',
    );
    return result.map((map) => Note.fromMap(map)).toList();
  }

  Future<List<Note>> getAllNotes() async {
    final db = await instance.database;
    final result =
        await db.query('notes', orderBy: 'pinned DESC, createdAt DESC');
    return result.map((map) => Note.fromMap(map)).toList();
  }

  Future<Note?> getNote(int id) async {
    final db = await instance.database;
    final result =
        await db.query('notes', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) return Note.fromMap(result.first);
    return null;
  }

  // ---------- FOLDERY ----------

  Future<int> insertFolder(NoteFolder folder) async {
    final db = await instance.database;
    return await db.insert('folders', folder.toMap());
  }

  Future<int> updateFolder(NoteFolder folder) async {
    final db = await instance.database;
    return await db.update(
      'folders',
      folder.toMap(),
      where: 'id = ?',
      whereArgs: [folder.id],
    );
  }

  // Usuniecie folderu; notatki w nim wracaja do "bez folderu"
  Future<void> deleteFolder(int id) async {
    final db = await instance.database;
    await db.update('notes', {'folderId': null},
        where: 'folderId = ?', whereArgs: [id]);
    await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<NoteFolder>> getAllFolders() async {
    final db = await instance.database;
    final result = await db.query('folders', orderBy: 'name ASC');
    return result.map((map) => NoteFolder.fromMap(map)).toList();
  }

  // Liczba notatek w danym folderze (do wyswietlenia licznika)
  Future<int> countNotesInFolder(int folderId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM notes WHERE folderId = ?', [folderId]);
    return (result.first['c'] as int?) ?? 0;
  }

  Future<int> countNotesNoFolder() async {
    final db = await instance.database;
    final result = await db
        .rawQuery('SELECT COUNT(*) AS c FROM notes WHERE folderId IS NULL');
    return (result.first['c'] as int?) ?? 0;
  }

  // ---------- IMPORT (zapis calej kopii) ----------

  // Czysci baze i wgrywa dane z kopii. Zwraca liczbe notatek.
  Future<int> replaceAllData(
      List<Note> notes, List<NoteFolder> folders) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('notes');
      await txn.delete('folders');
      // Mapowanie starych id folderow na nowe
      final Map<int, int> folderIdMap = {};
      for (final f in folders) {
        final oldId = f.id;
        final newId = await txn.insert('folders', {
          'name': f.name,
          'createdAt': f.createdAt,
        });
        if (oldId != null) folderIdMap[oldId] = newId;
      }
      for (final n in notes) {
        final mapped = n.toMap();
        mapped.remove('id'); // pozwalamy bazie nadac nowe id
        // Przemapuj folderId na nowe
        if (n.folderId != null && folderIdMap.containsKey(n.folderId)) {
          mapped['folderId'] = folderIdMap[n.folderId];
        } else {
          mapped['folderId'] = null;
        }
        await txn.insert('notes', mapped);
      }
    });
    return notes.length;
  }
}
