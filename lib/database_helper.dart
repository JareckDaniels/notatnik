import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'note.dart';
import 'folder.dart';

// Tryby sortowania notatek
enum SortMode {
  manual, // reczna kolejnosc (przeciaganie) - wg pola position
  newest, // najnowsze na gorze
  oldest, // najstarsze na gorze
  alphabetical, // alfabetycznie po tytule A-Z
}

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
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

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
        folderId INTEGER,
        position INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        expanded INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE notes ADD COLUMN colorIndex INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE notes ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE notes ADD COLUMN folderId INTEGER');
      await db.execute('''
        CREATE TABLE folders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          createdAt INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE notes ADD COLUMN position INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE folders ADD COLUMN position INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE folders ADD COLUMN expanded INTEGER NOT NULL DEFAULT 0');
      // Nadaj poczatkowe position wg dotychczasowej kolejnosci (createdAt)
      final notes = await db.query('notes', orderBy: 'createdAt DESC');
      for (int i = 0; i < notes.length; i++) {
        await db.update('notes', {'position': i},
            where: 'id = ?', whereArgs: [notes[i]['id']]);
      }
      final folders = await db.query('folders', orderBy: 'name ASC');
      for (int i = 0; i < folders.length; i++) {
        await db.update('folders', {'position': i},
            where: 'id = ?', whereArgs: [folders[i]['id']]);
      }
    }
  }

  // Buduje klauzule ORDER BY dla danego trybu sortowania.
  // Przypiete zawsze na gorze.
  String _orderBy(SortMode mode) {
    switch (mode) {
      case SortMode.manual:
        return 'pinned DESC, position ASC';
      case SortMode.newest:
        return 'pinned DESC, createdAt DESC';
      case SortMode.oldest:
        return 'pinned DESC, createdAt ASC';
      case SortMode.alphabetical:
        return 'pinned DESC, title COLLATE NOCASE ASC';
    }
  }

  // ---------- NOTATKI ----------

  Future<int> insertNote(Note note) async {
    final db = await instance.database;
    // Nowa notatka na gore reki: position = min - 1
    final minRow = await db
        .rawQuery('SELECT MIN(position) AS m FROM notes');
    final minPos = (minRow.first['m'] as int?) ?? 0;
    final map = note.toMap();
    map['position'] = minPos - 1;
    return await db.insert('notes', map);
  }

  Future<int> updateNote(Note note) async {
    final db = await instance.database;
    return await db.update('notes', note.toMap(),
        where: 'id = ?', whereArgs: [note.id]);
  }

  Future<int> deleteNote(int id) async {
    final db = await instance.database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Note>> getNotes({
    int? folderId,
    bool noFolder = false,
    SortMode sort = SortMode.manual,
  }) async {
    final db = await instance.database;
    String? where;
    List<Object?>? whereArgs;
    if (noFolder) {
      where = 'folderId IS NULL';
    } else if (folderId != null) {
      where = 'folderId = ?';
      whereArgs = [folderId];
    }
    final result = await db.query('notes',
        where: where, whereArgs: whereArgs, orderBy: _orderBy(sort));
    return result.map((m) => Note.fromMap(m)).toList();
  }

  Future<List<Note>> getAllNotes({SortMode sort = SortMode.manual}) async {
    final db = await instance.database;
    final result = await db.query('notes', orderBy: _orderBy(sort));
    return result.map((m) => Note.fromMap(m)).toList();
  }

  // Wyszukiwanie po tytule i tresci (wszystkie notatki, niezaleznie od folderu)
  Future<List<Note>> searchNotes(String query,
      {SortMode sort = SortMode.manual}) async {
    final db = await instance.database;
    final q = '%${query.toLowerCase()}%';
    final result = await db.query(
      'notes',
      where: 'LOWER(title) LIKE ? OR LOWER(content) LIKE ?',
      whereArgs: [q, q],
      orderBy: _orderBy(sort),
    );
    return result.map((m) => Note.fromMap(m)).toList();
  }

  Future<Note?> getNote(int id) async {
    final db = await instance.database;
    final result =
        await db.query('notes', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) return Note.fromMap(result.first);
    return null;
  }

  // Zapis nowej kolejnosci notatek (po przeciaganiu)
  Future<void> saveNotesOrder(List<Note> notes) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      for (int i = 0; i < notes.length; i++) {
        await txn.update('notes', {'position': i},
            where: 'id = ?', whereArgs: [notes[i].id]);
      }
    });
  }

  // ---------- FOLDERY ----------

  Future<int> insertFolder(NoteFolder folder) async {
    final db = await instance.database;
    final maxRow =
        await db.rawQuery('SELECT MAX(position) AS m FROM folders');
    final maxPos = (maxRow.first['m'] as int?) ?? -1;
    final map = folder.toMap();
    map['position'] = maxPos + 1;
    return await db.insert('folders', map);
  }

  Future<int> updateFolder(NoteFolder folder) async {
    final db = await instance.database;
    return await db.update('folders', folder.toMap(),
        where: 'id = ?', whereArgs: [folder.id]);
  }

  Future<void> deleteFolder(int id) async {
    final db = await instance.database;
    await db.update('notes', {'folderId': null},
        where: 'folderId = ?', whereArgs: [id]);
    await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<NoteFolder>> getAllFolders() async {
    final db = await instance.database;
    final result = await db.query('folders', orderBy: 'position ASC');
    return result.map((m) => NoteFolder.fromMap(m)).toList();
  }

  // Przelaczenie stanu otwarty/zamkniety
  Future<void> setFolderExpanded(int id, bool expanded) async {
    final db = await instance.database;
    await db.update('folders', {'expanded': expanded ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  // Zapis nowej kolejnosci folderow (po przeciaganiu)
  Future<void> saveFoldersOrder(List<NoteFolder> folders) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      for (int i = 0; i < folders.length; i++) {
        await txn.update('folders', {'position': i},
            where: 'id = ?', whereArgs: [folders[i].id]);
      }
    });
  }

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

  // ---------- IMPORT ----------

  Future<int> replaceAllData(
      List<Note> notes, List<NoteFolder> folders) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('notes');
      await txn.delete('folders');
      final Map<int, int> folderIdMap = {};
      for (int i = 0; i < folders.length; i++) {
        final f = folders[i];
        final oldId = f.id;
        final newId = await txn.insert('folders', {
          'name': f.name,
          'createdAt': f.createdAt,
          'position': i,
          'expanded': f.expanded ? 1 : 0,
        });
        if (oldId != null) folderIdMap[oldId] = newId;
      }
      for (int i = 0; i < notes.length; i++) {
        final n = notes[i];
        final mapped = n.toMap();
        mapped.remove('id');
        mapped['position'] = i;
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
