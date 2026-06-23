import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'note.dart';
import 'folder.dart';
import 'database_helper.dart';

// Obsluga eksportu i importu kopii zapasowej w formacie JSON.
class BackupService {
  static const int _formatVersion = 1;

  // Tworzy plik kopii i otwiera systemowe okno udostepniania,
  // dzieki czemu uzytkownik moze zapisac go gdziekolwiek lub wyslac.
  static Future<void> exportBackup() async {
    final notes = await DatabaseHelper.instance.getAllNotes();
    final folders = await DatabaseHelper.instance.getAllFolders();

    final data = {
      'format': _formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'folders': folders.map((f) => f.toJson()).toList(),
      'notes': notes.map((n) => n.toJson()).toList(),
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

    // Zapis do pliku tymczasowego z czytelna nazwa (z data)
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/notatki_kopia_$stamp.json');
    await file.writeAsString(jsonStr);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Kopia zapasowa notatek',
      text: 'Kopia zapasowa aplikacji Notatki ($stamp)',
    );
  }

  // Wynik importu do pokazania uzytkownikowi
  static Future<ImportResult> importBackup() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) {
      return ImportResult(success: false, message: 'Nie wybrano pliku');
    }

    try {
      final f = picked.files.first;
      String content;
      if (f.bytes != null) {
        content = utf8.decode(f.bytes!);
      } else if (f.path != null) {
        content = await File(f.path!).readAsString();
      } else {
        return ImportResult(
            success: false, message: 'Nie udalo sie odczytac pliku');
      }

      final data = jsonDecode(content) as Map<String, dynamic>;

      final foldersJson = (data['folders'] as List?) ?? [];
      final notesJson = (data['notes'] as List?) ?? [];

      final folders = foldersJson
          .map((e) => NoteFolder.fromJson(e as Map<String, dynamic>))
          .toList();
      final notes = notesJson
          .map((e) => Note.fromJson(e as Map<String, dynamic>))
          .toList();

      final count =
          await DatabaseHelper.instance.replaceAllData(notes, folders);

      return ImportResult(
        success: true,
        message: 'Zaimportowano $count notatek',
        importedNotes: count,
      );
    } catch (e) {
      debugPrint('Blad importu: $e');
      return ImportResult(
        success: false,
        message: 'Plik jest nieprawidlowy lub uszkodzony',
      );
    }
  }
}

class ImportResult {
  final bool success;
  final String message;
  final int importedNotes;

  ImportResult({
    required this.success,
    required this.message,
    this.importedNotes = 0,
  });
}
