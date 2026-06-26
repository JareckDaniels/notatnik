import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../folder.dart';
import '../note.dart';
import '../database_helper.dart';
import '../notification_service.dart';
import '../note_colors.dart';
import '../settings_store.dart';
import 'note_edit_screen.dart';
import 'settings_screen.dart';
import 'trash_screen.dart';

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  List<NoteFolder> _folders = [];
  List<Note> _looseNotes = []; // notatki bez folderu
  final Map<int, List<Note>> _folderNotes = {}; // notatki w folderach
  final Map<int, int> _counts = {};
  SortMode _sort = SortMode.manual;
  int _trashCount = 0;
  bool _loading = true;

  // Wyszukiwanie
  bool _searching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  List<Note> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _sort = await SettingsStore.getSortMode();
    await _load();
    // Reaguj na tapniecia powiadomien w trakcie dzialania apki
    NotificationService.setOnNotificationTap(_openPendingNote);
    // Sprawdz, czy apka zostala otwarta przez powiadomienie
    _openPendingNote();
  }

  // Otwiera notatke wskazana przez klikniete powiadomienie (jesli jest)
  Future<void> _openPendingNote() async {
    final id = NotificationService.pendingNoteId;
    if (id == null) return;
    NotificationService.pendingNoteId = null; // zuzyj raz
    final note = await DatabaseHelper.instance.getNote(id);
    if (note == null || !mounted) return;
    // Nie otwieraj notatki z kosza
    if (note.deletedAt != null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NoteEditScreen(note: note)),
    );
    if (changed == true) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final folders = await DatabaseHelper.instance.getAllFolders();
    final loose =
        await DatabaseHelper.instance.getNotes(noFolder: true, sort: _sort);
    final trashCount = await DatabaseHelper.instance.countTrash();

    _folderNotes.clear();
    _counts.clear();
    for (final f in folders) {
      if (f.id != null) {
        final notes = await DatabaseHelper.instance
            .getNotes(folderId: f.id, sort: _sort);
        _folderNotes[f.id!] = notes;
        _counts[f.id!] = notes.length;
      }
    }
    if (!mounted) return;
    setState(() {
      _folders = folders;
      _looseNotes = loose;
      _trashCount = trashCount;
      _loading = false;
    });
  }

  // Podglad pozycji listy na kafelku (do 5 pozycji)
  List<Widget> _buildListPreview(Note note) {
    List items;
    try {
      items = jsonDecode(note.listItems) as List;
    } catch (_) {
      return [];
    }
    if (items.isEmpty) return [];
    final shown = items.take(5).toList();
    final widgets = <Widget>[];
    for (final raw in shown) {
      final m = raw as Map<String, dynamic>;
      final text = (m['text'] as String?) ?? '';
      final checked = (m['checked'] as bool?) ?? false;
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              checked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 16,
              color: checked
                  ? Theme.of(context).colorScheme.outline
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.2,
                      decoration:
                          checked ? TextDecoration.lineThrough : null,
                      color: checked
                          ? Theme.of(context).colorScheme.outline
                          : null,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ));
    }
    if (items.length > 5) {
      widgets.add(Text(
        '+${items.length - 5} więcej',
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.outline),
      ));
    }
    return widgets;
  }

  // Formatuje date "po ludzku": dzis / wczoraj / data
  String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Dzis, ${DateFormat('HH:mm').format(d)}';
    if (diff == 1) return 'Wczoraj, ${DateFormat('HH:mm').format(d)}';
    if (diff < 7) return DateFormat('EEEE, HH:mm', 'pl').format(d);
    return DateFormat('dd.MM.yyyy').format(d);
  }

  // ---------- akcje notatek ----------

  Future<void> _openNote(Note note) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NoteEditScreen(note: note)),
    );
    if (changed == true) _load();
  }

  Future<void> _addNote({int? folderId}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => NoteEditScreen(defaultFolderId: folderId)),
    );
    if (changed == true) _load();
  }

  Future<void> _deleteNote(Note note) async {
    if (note.id == null) return;
    // Przypomnienie anulujemy - notatka idzie do kosza
    await NotificationService.instance.cancelReminder(note.id!);
    await DatabaseHelper.instance.moveToTrash(note.id!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Przeniesiono do kosza'),
          action: SnackBarAction(
            label: 'Cofnij',
            onPressed: () async {
              await DatabaseHelper.instance.restoreFromTrash(note.id!);
              _load();
            },
          ),
        ),
      );
    }
    _load();
  }

  Future<void> _togglePin(Note note) async {
    await DatabaseHelper.instance
        .updateNote(note.copyWith(pinned: !note.pinned));
    _load();
  }

  // ---------- akcje folderow ----------

  Future<void> _addFolder() async {
    final name = await _folderNameDialog();
    if (name == null || name.trim().isEmpty) return;
    await DatabaseHelper.instance.insertFolder(NoteFolder(
        name: name.trim(),
        createdAt: DateTime.now().millisecondsSinceEpoch));
    _load();
  }

  Future<void> _renameFolder(NoteFolder folder) async {
    final name = await _folderNameDialog(initial: folder.name);
    if (name == null || name.trim().isEmpty) return;
    await DatabaseHelper.instance
        .updateFolder(folder.copyWith(name: name.trim()));
    _load();
  }

  Future<void> _toggleFolderExpanded(NoteFolder folder) async {
    if (folder.id == null) return;
    await DatabaseHelper.instance
        .setFolderExpanded(folder.id!, !folder.expanded);
    _load();
  }

  Future<void> _deleteFolder(NoteFolder folder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usunąć folder?'),
        content: Text(
            'Folder "${folder.name}" zostanie usunięty. Notatki w nim trafią do listy bez folderu.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Anuluj')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Usuń')),
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
        title: Text(initial == null ? 'Nowy folder' : 'Zmień nazwę'),
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

  // ---------- sortowanie ----------

  Future<void> _pickSort() async {
    final selected = await showModalBottomSheet<SortMode>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sortowanie',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            _sortTile(SortMode.manual, 'Wlasna kolejnosc (przeciaganie)',
                Icons.drag_handle),
            _sortTile(SortMode.newest, 'Najnowsze na gorze',
                Icons.arrow_downward),
            _sortTile(SortMode.oldest, 'Najstarsze na gorze',
                Icons.arrow_upward),
            _sortTile(SortMode.alphabetical, 'Alfabetycznie A-Z',
                Icons.sort_by_alpha),
            _sortTile(SortMode.reminder, 'Wg przypomnienia (najbliższe)',
                Icons.notifications_active),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null && selected != _sort) {
      _sort = selected;
      await SettingsStore.setSortMode(selected);
      _load();
    }
  }

  Widget _sortTile(SortMode mode, String label, IconData icon) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: _sort == mode
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () => Navigator.pop(context, mode),
    );
  }

  // ---------- wyszukiwanie ----------

  void _startSearch() {
    setState(() {
      _searching = true;
      _searchResults = [];
      _searchCtrl.clear();
    });
  }

  void _stopSearch() {
    setState(() {
      _searching = false;
      _searchResults = [];
      _searchCtrl.clear();
    });
  }

  Future<void> _runSearch(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final results =
        await DatabaseHelper.instance.searchNotes(q.trim(), sort: _sort);
    if (!mounted) return;
    setState(() => _searchResults = results);
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Szukaj w notatkach...',
                  border: InputBorder.none,
                ),
                onChanged: _runSearch,
              )
            : const Text('Notatki'),
        actions: _searching
            ? [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _stopSearch,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Szukaj',
                  onPressed: _startSearch,
                ),
                IconButton(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Sortowanie',
                  onPressed: _pickSort,
                ),
                IconButton(
                  icon: Badge(
                    label: Text('$_trashCount'),
                    isLabelVisible: _trashCount > 0,
                    child: const Icon(Icons.delete_outline),
                  ),
                  tooltip: 'Kosz',
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TrashScreen()),
                    );
                    _load();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: 'Ustawienia',
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    );
                    _load();
                  },
                ),
              ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _searching
              ? _buildSearchResults()
              : _buildMainList(),
      floatingActionButton: _searching
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'fab_note',
                  onPressed: () => _addNote(),
                  tooltip: 'Nowa notatka',
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'fab_folder',
                  onPressed: _addFolder,
                  tooltip: 'Nowy folder',
                  child: const Icon(Icons.create_new_folder_outlined),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchCtrl.text.trim().isEmpty) {
      return Center(
        child: Text('Wpisz tekst, aby wyszukac',
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      );
    }
    if (_searchResults.isEmpty) {
      return Center(
        child: Text('Brak wynikow',
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _searchResults.length,
      itemBuilder: (_, i) => _noteTile(_searchResults[i]),
    );
  }

  // Glowna lista: luzne notatki -> foldery
  Widget _buildMainList() {
    final allowReorder = _sort == SortMode.manual;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              12, 12, 12, 12 + MediaQuery.of(context).viewPadding.bottom + 72),
          children: [
            // --- LUZNE NOTATKI (nad folderami) ---
            if (_looseNotes.isNotEmpty) ...[
              if (allowReorder)
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorder: (oldI, newI) => _reorderLoose(oldI, newI),
                  children: [
                    for (int i = 0; i < _looseNotes.length; i++)
                      _noteTile(_looseNotes[i],
                          key: ValueKey('loose_${_looseNotes[i].id}'),
                          reorderIndex: i),
                  ],
                )
              else
                ..._looseNotes.map((n) => _noteTile(n)),
              const SizedBox(height: 8),
            ],

            // --- FOLDERY ---
            if (_folders.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Text('Foldery',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.outline)),
              ),
              if (allowReorder)
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorder: (oldI, newI) => _reorderFolders(oldI, newI),
                  children: [
                    for (int i = 0; i < _folders.length; i++)
                      _folderBlock(_folders[i],
                          key: ValueKey('folder_${_folders[i].id}'),
                          reorderIndex: i),
                  ],
                )
              else
                ..._folders.map((f) => _folderBlock(f)),
            ],

            if (_looseNotes.isEmpty && _folders.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.note_alt_outlined,
                          size: 72,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 12),
                      Text('Brak notatek i folderów',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('Dodaj coś przyciskami w prawym dolnym rogu',
                          style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.outline)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 100), // miejsce pod FAB
          ],
        ),
      ),
    );
  }

  // Blok folderu: naglowek + (jesli otwarty) notatki pod spodem
  Widget _folderBlock(NoteFolder f, {Key? key, int? reorderIndex}) {
    final count = f.id != null ? (_counts[f.id!] ?? 0) : 0;
    final notes = f.id != null ? (_folderNotes[f.id!] ?? []) : <Note>[];
    final allowReorder = _sort == SortMode.manual;

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: ListTile(
            leading: Icon(
              f.expanded ? Icons.folder_open : Icons.folder,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(f.name),
            subtitle: Text('$count notatek'),
            onTap: () => _toggleFolderExpanded(f),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'rename') _renameFolder(f);
                    if (v == 'delete') _deleteFolder(f);
                    if (v == 'addnote') _addNote(folderId: f.id);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'addnote',
                        child: Row(children: [
                          Icon(Icons.note_add_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('Dodaj notatkę')
                        ])),
                    const PopupMenuItem(
                        value: 'rename',
                        child: Row(children: [
                          Icon(Icons.edit_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('Zmień nazwę')
                        ])),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline, size: 20),
                          SizedBox(width: 8),
                          Text('Usuń')
                        ])),
                  ],
                ),
                // Uchwyt przeciagania przy samej prawej krawedzi
                if (allowReorder && reorderIndex != null)
                  ReorderableDragStartListener(
                    index: reorderIndex,
                    child: Container(
                      padding: const EdgeInsets.only(left: 4, right: 8),
                      color: Colors.transparent,
                      child: Icon(Icons.drag_handle,
                          size: 24,
                          color: Theme.of(context).colorScheme.outline),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Notatki folderu widoczne tylko gdy otwarty
        if (f.expanded)
          Container(
            margin: const EdgeInsets.only(left: 12, bottom: 8, top: 2),
            padding: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              // Pionowa linia po lewej - pokazuje "zawartosc folderu"
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                  width: 3,
                ),
              ),
            ),
            child: notes.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('(pusty folder)',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.outline)),
                  )
                : Column(
                    children: notes.map((n) => _noteTile(n)).toList(),
                  ),
          ),
      ],
    );
  }

  // Pojedyncza notatka jako kafelek listy
  Widget _noteTile(Note note, {Key? key, int? reorderIndex}) {
    final brightness = Theme.of(context).brightness;
    final cardColor = NoteColors.colorFor(note.colorIndex, brightness);
    final hasReminder = note.reminderAt != null;
    final reminderPast = hasReminder &&
        note.reminderAt! < DateTime.now().millisecondsSinceEpoch;
    final reminderText = hasReminder
        ? DateFormat('dd.MM.yyyy HH:mm')
            .format(DateTime.fromMillisecondsSinceEpoch(note.reminderAt!))
        : null;
    final allowReorder = _sort == SortMode.manual;

    return Card(
      key: key,
      color: cardColor,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _openNote(note),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note.title.isNotEmpty)
                      Row(
                        children: [
                          if (note.pinned)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(Icons.push_pin,
                                  size: 15,
                                  color:
                                      Theme.of(context).colorScheme.primary),
                            ),
                          Expanded(
                            child: Text(
                              note.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                      fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (note.title.isEmpty && note.pinned)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Icon(Icons.push_pin,
                            size: 15,
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    if (note.isList) ...[
                      if (note.title.isNotEmpty) const SizedBox(height: 4),
                      ..._buildListPreview(note),
                    ] else if (note.content.isNotEmpty) ...[
                      if (note.title.isNotEmpty) const SizedBox(height: 2),
                      Text(
                        note.content,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(height: 1.25),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (hasReminder) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                              reminderPast
                                  ? Icons.notification_important
                                  : Icons.notifications_active,
                              size: 14,
                              color: reminderPast
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                                reminderPast
                                    ? '$reminderText (minęło)'
                                    : reminderText!,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                        color: reminderPast
                                            ? Theme.of(context)
                                                .colorScheme
                                                .error
                                            : Theme.of(context)
                                                .colorScheme
                                                .primary,
                                        fontWeight: reminderPast
                                            ? FontWeight.bold
                                            : FontWeight.normal),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                    // Malutka, ledwo widoczna data utworzenia
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(note.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (v) {
                  if (v == 'pin') _togglePin(note);
                  if (v == 'delete') _deleteNote(note);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'pin',
                    child: Row(children: [
                      Icon(
                          note.pinned
                              ? Icons.push_pin_outlined
                              : Icons.push_pin,
                          size: 20),
                      const SizedBox(width: 8),
                      Text(note.pinned ? 'Odepnij' : 'Przypnij'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 20),
                      SizedBox(width: 8),
                      Text('Usuń'),
                    ]),
                  ),
                ],
              ),
              // Uchwyt przeciagania przy samej prawej krawedzi
              if (allowReorder && reorderIndex != null)
                ReorderableDragStartListener(
                  index: reorderIndex,
                  child: Container(
                    padding: const EdgeInsets.only(left: 4, right: 8),
                    color: Colors.transparent,
                    child: Icon(Icons.drag_handle,
                        size: 24,
                        color: Theme.of(context).colorScheme.outline),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- reorder ----------

  Future<void> _reorderLoose(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _looseNotes.removeAt(oldIndex);
      _looseNotes.insert(newIndex, item);
    });
    await DatabaseHelper.instance.saveNotesOrder(_looseNotes);
  }

  Future<void> _reorderFolders(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _folders.removeAt(oldIndex);
      _folders.insert(newIndex, item);
    });
    await DatabaseHelper.instance.saveFoldersOrder(_folders);
  }
}
