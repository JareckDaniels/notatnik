import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';

// Prosty magazyn drobnych ustawien aplikacji (poza powiadomieniami).
class SettingsStore {
  static const _sortKey = 'sort_mode';
  static const _autoBackupKey = 'auto_backup_enabled';
  static const _autoBackupPathKey = 'auto_backup_path';
  static const _lastBackupKey = 'last_backup_ms';

  // --- sortowanie ---
  static Future<SortMode> getSortMode() async {
    final prefs = await SharedPreferences.getInstance();
    final i = prefs.getInt(_sortKey) ?? SortMode.manual.index;
    return SortMode.values[i];
  }

  static Future<void> setSortMode(SortMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sortKey, mode.index);
  }

  // --- automatyczny backup ---
  static Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoBackupKey) ?? false;
  }

  static Future<void> setAutoBackupEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBackupKey, v);
  }

  static Future<String?> getAutoBackupPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_autoBackupPathKey);
  }

  static Future<void> setAutoBackupPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove(_autoBackupPathKey);
    } else {
      await prefs.setString(_autoBackupPathKey, path);
    }
  }

  static Future<int?> getLastBackupMs() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_lastBackupKey);
    return v == 0 ? null : v;
  }

  static Future<void> setLastBackupMs(int ms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastBackupKey, ms);
  }
}
