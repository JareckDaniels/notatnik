import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'note.dart';

// Singleton zarządzający bazą danych SQLite
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
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        reminderAt INTEGER
      )
    ''');
  }

  // Dodanie notatki, zwraca jej id
  Future<int> insertNote(Note note) async {
    final db = await instance.database;
    return await db.insert('notes', note.toMap());
  }

  // Aktualizacja notatki
  Future<int> updateNote(Note note) async {
    final db = await instance.database;
    return await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  // Usunięcie notatki
  Future<int> deleteNote(int id) async {
    final db = await instance.database;
    return await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Pobranie wszystkich notatek (najnowsze na górze)
  Future<List<Note>> getAllNotes() async {
    final db = await instance.database;
    final result = await db.query('notes', orderBy: 'createdAt DESC');
    return result.map((map) => Note.fromMap(map)).toList();
  }

  // Pobranie pojedynczej notatki
  Future<Note?> getNote(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return Note.fromMap(result.first);
    }
    return null;
  }
}
