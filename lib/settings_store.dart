import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';

// Prosty magazyn drobnych ustawien aplikacji (poza powiadomieniami).
class SettingsStore {
  static const _sortKey = 'sort_mode';

  static Future<SortMode> getSortMode() async {
    final prefs = await SharedPreferences.getInstance();
    final i = prefs.getInt(_sortKey) ?? SortMode.manual.index;
    return SortMode.values[i];
  }

  static Future<void> setSortMode(SortMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sortKey, mode.index);
  }
}
