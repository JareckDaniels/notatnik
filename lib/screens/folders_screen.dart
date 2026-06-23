import 'package:flutter/material.dart';
import '../folder.dart';
import '../database_helper.dart';
import 'notes_list_screen.dart';
import 'note_edit_screen.dart';
import 'settings_screen.dart';

// Ekran glowny: lista folderow + skroty "Wszystkie" i "Bez folderu".
class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  List<NoteFolder> _folders = [];
  Map<int, int> _counts = {}; // folderId -> liczba notatek
  int _allCount = 0;
  int _noFolderCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final folders = await DatabaseHelper.instance.getAllFolders();
    final all = await DatabaseHelper.instance.getAllNotes();
    final noFolder = await DatabaseHelper.instance.countNotesNoFolder();
    final counts = <int, int>{};
    for (final f in folders) {
      if (f.id != null) {
        counts[f.id!] =
            await DatabaseHelper.instance.countNotesInFolder(f.id!);
      }
    }
    if (!mounted) return;
    setState(() {
      _folders = folders;
      _counts = counts;
      _allCount = all.length;
      _noFolderCount = noFolder;
      _loading = false;
    });
  }

  Future<void> _openNotes({int? folderId, bool noFolder = false, String? title}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotesListScreen(
          folderId: folderId,
          noFolderOnly: noFolder,
          screenTitle: title ?? 'Notatki',
        ),
      ),
    );
    _load(); // odswiez liczniki po powrocie
  }

  // Szybkie utworzenie notatki z ekranu glownego (bez folderu)
  Future<void> _addNote() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const NoteEditScreen(),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _addFolder() async {
    final name = await _folderNameDialog();
    if (name == null || name.trim().isEmpty) return;
    await DatabaseHelper.instance.insertFolder(
      NoteFolder(name: name.trim(), createdAt: DateTime.now().millisecondsSinceEpoch),
    );
    _load();
  }

  Future<void> _renameFolder(NoteFolder folder) async {
    final name = await _folderNameDialog(initial: folder.name);
    if (name == null || name.trim().isEmpty) return;
    await DatabaseHelper.instance.updateFolder(
      NoteFolder(id: folder.id, name: name.trim(), createdAt: folder.createdAt),
    );
    _load();
  }

  Future<void> _deleteFolder(NoteFolder folder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usunac folder?'),
        content: Text(
            'Folder "${folder.name}" zostanie usuniety. Notatki w nim trafia do "Bez folderu".'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Anuluj')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Usun')),
        ],
      ),
    );
    if (confirm == true && folder.id != null) {
      await DatabaseHelper.instance.deleteFolder(folder.id!);
      _load();
    }
  }

  Future<String?> _folderNameDialog({String? initial}) {
    final controller = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(initial == null ? 'Nowy folder' : 'Zmien nazwe'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nazwa folderu'),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anuluj')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Zapisz')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notatki'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Ustawienia',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _shortcutTile(
                      icon: Icons.notes,
                      title: 'Wszystkie notatki',
                      count: _allCount,
                      onTap: () => _openNotes(title: 'Wszystkie notatki'),
                    ),
                    _shortcutTile(
                      icon: Icons.inbox_outlined,
                      title: 'Bez folderu',
                      count: _noFolderCount,
                      onTap: () => _openNotes(
                          noFolder: true, title: 'Bez folderu'),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(8, 16, 8, 8),
                      child: Text('Foldery',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    if (_folders.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Brak folderow. Dodaj pierwszy przyciskiem ponizej.',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.outline),
                        ),
                      )
                    else
                      ..._folders.map((f) => _folderTile(f)),
                  ],
                ),
              ),
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'fab_note',
            onPressed: _addNote,
            icon: const Icon(Icons.add),
            label: const Text('Nowa notatka'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'fab_folder',
            onPressed: _addFolder,
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Nowy folder'),
          ),
        ],
      ),
    );
  }

  Widget _shortcutTile({
    required IconData icon,
    required String title,
    required int count,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        trailing: Text('$count',
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        onTap: onTap,
      ),
    );
  }

  Widget _folderTile(NoteFolder f) {
    final count = f.id != null ? (_counts[f.id!] ?? 0) : 0;
    return Card(
      child: ListTile(
        leading: Icon(Icons.folder,
            color: Theme.of(context).colorScheme.primary),
        title: Text(f.name),
        subtitle: Text('$count notatek'),
        onTap: () => _openNotes(folderId: f.id, title: f.name),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'rename') _renameFolder(f);
            if (v == 'delete') _deleteFolder(f);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'rename',
                child: Row(children: [
                  Icon(Icons.edit_outlined, size: 20),
                  SizedBox(width: 8),
                  Text('Zmien nazwe')
                ])),
            const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, size: 20),
                  SizedBox(width: 8),
                  Text('Usun')
                ])),
          ],
        ),
      ),
    );
  }
}
