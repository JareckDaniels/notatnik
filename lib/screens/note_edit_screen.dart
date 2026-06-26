import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../note.dart';
import '../folder.dart';
import '../database_helper.dart';
import '../notification_service.dart';
import '../note_colors.dart';
import '../widgets/wheel_time_picker.dart';

class NoteEditScreen extends StatefulWidget {
  final Note? note;
  final int? defaultFolderId; // folder, w ktorym tworzymy nowa notatke
  const NoteEditScreen({super.key, this.note, this.defaultFolderId});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  DateTime? _reminder;
  bool _forceAlarm = false;
  bool _isList = false;
  List<ListItem> _items = [];
  // Kontrolery i ogniska dla pozycji listy (zywe pola tekstowe)
  final List<TextEditingController> _itemControllers = [];
  final List<FocusNode> _itemFocusNodes = [];
  int _colorIndex = 0;
  bool _pinned = false;
  int? _folderId;
  List<NoteFolder> _folders = [];
  // Stan rozwiniecia zwijanych sekcji
  bool _colorExpanded = false;
  bool _folderExpanded = false;
  bool _skipSave = false; // gdy true, PopScope nie zapisuje (np. po usunieciu)

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController =
        TextEditingController(text: widget.note?.content ?? '');
    if (widget.note?.reminderAt != null) {
      _reminder =
          DateTime.fromMillisecondsSinceEpoch(widget.note!.reminderAt!);
    }
    _colorIndex = widget.note?.colorIndex ?? 0;
    _forceAlarm = widget.note?.forceAlarm ?? false;
    _pinned = widget.note?.pinned ?? false;
    _folderId = widget.note?.folderId ?? widget.defaultFolderId;
    _isList = widget.note?.isList ?? false;
    _loadListItems();
    _loadFolders();
  }

  // Wczytuje pozycje listy z JSON i tworzy dla nich kontrolery
  void _loadListItems() {
    if (widget.note?.listItems != null) {
      try {
        final decoded = jsonDecode(widget.note!.listItems) as List;
        _items = decoded
            .map((e) => ListItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _items = [];
      }
    }
    _rebuildItemControllers();
    if (_isList) _ensureTrailingEmpty();
  }

  // Odtwarza kontrolery i ogniska tak, by bylo ich tyle co pozycji
  void _rebuildItemControllers() {
    for (final c in _itemControllers) {
      c.dispose();
    }
    for (final f in _itemFocusNodes) {
      f.dispose();
    }
    _itemControllers.clear();
    _itemFocusNodes.clear();
    for (final item in _items) {
      _itemControllers.add(TextEditingController(text: item.text));
      _itemFocusNodes.add(FocusNode());
    }
  }

  // Przepisuje aktualne teksty z kontrolerow do _items (przed zapisem/sortem)
  void _syncItemsFromControllers() {
    for (int i = 0; i < _items.length && i < _itemControllers.length; i++) {
      _items[i] = _items[i].copyWith(text: _itemControllers[i].text);
    }
  }

  // Nazwa aktualnie wybranego folderu (do podpisu zwinietej sekcji)
  String _folderName() {
    if (_folderId == null) return 'Bez folderu';
    final f = _folders.where((f) => f.id == _folderId);
    return f.isEmpty ? 'Bez folderu' : f.first.name;
  }

  Future<void> _loadFolders() async {
    final folders = await DatabaseHelper.instance.getAllFolders();
    if (!mounted) return;
    setState(() => _folders = folders);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    for (final c in _itemControllers) {
      c.dispose();
    }
    for (final f in _itemFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final initialDate = _reminder ?? now.add(const Duration(hours: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 10)),
      helpText: 'Wybierz dzien przypomnienia',
    );
    if (date == null) return;
    if (!mounted) return;

    final time = await showDialog<TimeOfDay>(
      context: context,
      builder: (_) =>
          WheelTimePicker(initial: TimeOfDay.fromDateTime(initialDate)),
    );
    if (time == null) return;

    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);

    if (picked.isBefore(DateTime.now())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wybierz date w przyszlosci')),
      );
      return;
    }
    setState(() => _reminder = picked);
  }

  void _clearReminder() => setState(() => _reminder = null);

  // Odrzucenie nowej (jeszcze niezapisanej) notatki - bez zapisu
  Future<void> _discardNew() async {
    final hasContent = _titleController.text.trim().isNotEmpty ||
        _contentController.text.trim().isNotEmpty ||
        _items.any((e) => e.text.trim().isNotEmpty);
    if (hasContent) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Odrzucic notatke?'),
          content: const Text('Wpisane dane nie zostana zapisane.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Anuluj')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Odrzuc')),
          ],
        ),
      );
      if (confirm != true) return;
    }
    if (!mounted) return;
    _skipSave = true; // nie zapisuj przy zamykaniu
    Navigator.pop(context, false);
  }

  // Usuniecie notatki do kosza z poziomu edytora
  Future<void> _deleteNote() async {
    final note = widget.note;
    if (note?.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usunac do kosza?'),
        content: const Text(
            'Notatke mozna przywrocic z kosza w ciagu 30 dni.'),
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
    if (confirm != true) return;
    await NotificationService.instance.cancelReminder(note!.id!);
    await DatabaseHelper.instance.moveToTrash(note.id!);
    if (!mounted) return;
    _skipSave = true; // nie zapisuj ponownie przy zamykaniu
    Navigator.pop(context, true);
  }

  // Udostepnienie tresci notatki (mail, komunikatory, schowek...)
  Future<void> _shareNote() async {
    final title = _titleController.text.trim();
    String body;
    if (_isList) {
      // Lista -> tekst z haczykami
      body = _items
          .map((e) => '${e.checked ? "[x]" : "[ ]"} ${e.text}')
          .join('\n');
    } else {
      body = _contentController.text.trim();
    }
    final text = title.isEmpty ? body : '$title\n\n$body';
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notatka jest pusta')),
      );
      return;
    }
    await Share.share(text, subject: title.isEmpty ? null : title);
  }

  // Przelacza miedzy trybem tekstowym a lista
  void _toggleListMode() {
    setState(() {
      if (!_isList) {
        // Tekst -> lista: kazda niepusta linijka staje sie pozycja
        final text = _contentController.text.trim();
        if (text.isNotEmpty && _items.isEmpty) {
          _items = text
              .split('\n')
              .where((l) => l.trim().isNotEmpty)
              .map((l) => ListItem(text: l.trim()))
              .toList();
          _rebuildItemControllers();
        }
        _isList = true;
        _ensureTrailingEmpty();
      } else {
        // Lista -> tekst: pozycje wracaja jako linijki
        _syncItemsFromControllers();
        if (_items.isNotEmpty) {
          _contentController.text = _items.map((e) => e.text).join('\n');
        }
        _isList = false;
      }
    });
  }

  // Sortuje: nieodhaczone na gorze, odhaczone na dole.
  // Kontrolery i ogniska przestawiamy razem z pozycjami, by sie nie rozjechaly.
  void _sortItems() {
    _syncItemsFromControllers();
    final indexed = List.generate(_items.length, (i) => i);
    indexed.sort((a, b) {
      final ca = _items[a].checked ? 1 : 0;
      final cb = _items[b].checked ? 1 : 0;
      if (ca != cb) return ca - cb;
      return a.compareTo(b); // stabilnie - zachowaj kolejnosc
    });
    _items = [for (final i in indexed) _items[i]];
    final newCtrls = [for (final i in indexed) _itemControllers[i]];
    final newNodes = [for (final i in indexed) _itemFocusNodes[i]];
    _itemControllers
      ..clear()
      ..addAll(newCtrls);
    _itemFocusNodes
      ..clear()
      ..addAll(newNodes);
  }

  void _toggleItem(int index) {
    setState(() {
      _items[index] = _items[index].copyWith(checked: !_items[index].checked);
      _cleanupEmptyItems(); // usun ewentualne puste ze srodka
      _sortItems();
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _itemControllers.removeAt(index).dispose();
      _itemFocusNodes.removeAt(index).dispose();
    });
  }

  Future<void> _save({bool pop = true}) async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    _syncItemsFromControllers();
    // Pomijamy puste pozycje przy zapisie
    final cleanItems = _items.where((e) => e.text.trim().isNotEmpty).toList();
    final itemsJson =
        jsonEncode(cleanItems.map((e) => e.toJson()).toList());

    // Notatka pusta = brak tytulu, tresci ORAZ pozycji listy
    if (title.isEmpty && content.isEmpty && cleanItems.isEmpty) {
      if (pop && mounted) Navigator.pop(context, false);
      return;
    }

    final reminderMs = _reminder?.millisecondsSinceEpoch;

    if (widget.note == null) {
      final note = Note(
        title: title,
        content: content,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        reminderAt: reminderMs,
        colorIndex: _colorIndex,
        pinned: _pinned,
        folderId: _folderId,
        forceAlarm: _forceAlarm,
        isList: _isList,
        listItems: itemsJson,
      );
      final id = await DatabaseHelper.instance.insertNote(note);
      await _scheduleIfNeeded(id, title, content);
    } else {
      final updated = widget.note!.copyWith(
        title: title,
        content: content,
        reminderAt: reminderMs,
        clearReminder: reminderMs == null,
        colorIndex: _colorIndex,
        pinned: _pinned,
        folderId: _folderId,
        clearFolder: _folderId == null,
        forceAlarm: _forceAlarm,
        isList: _isList,
        listItems: itemsJson,
      );
      await DatabaseHelper.instance.updateNote(updated);
      await NotificationService.instance.cancelReminder(widget.note!.id!);
      await _scheduleIfNeeded(widget.note!.id!, title, content);
    }

    if (!mounted) return;
    if (pop) Navigator.pop(context, true);
  }

  Future<void> _scheduleIfNeeded(int id, String title, String content) async {
    if (_reminder != null) {
      await NotificationService.instance.scheduleReminder(
        id: id,
        title: title.isEmpty ? 'Notatka' : title,
        body: content.isEmpty ? 'Przypomnienie' : content,
        dateTime: _reminder!,
        forceAlarm: _forceAlarm,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgColor = NoteColors.colorFor(_colorIndex, brightness);
    final reminderText = _reminder != null
        ? DateFormat('dd.MM.yyyy, HH:mm').format(_reminder!)
        : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_skipSave) {
          if (mounted) Navigator.pop(context, true);
          return;
        }
        await _save(pop: false); // auto-zapis przy wyjsciu (wstecz/gest)
        if (mounted) Navigator.pop(context, true);
      },
      child: Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        titleSpacing: 0,
        title: Text(
          widget.note == null ? 'Nowa notatka' : 'Edycja',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        ),
        actions: [
          IconButton(
            icon: Icon(_isList ? Icons.subject : Icons.checklist),
            tooltip: _isList ? 'Zmien na tekst' : 'Zmien na liste',
            onPressed: _toggleListMode,
          ),
          IconButton(
            icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined),
            tooltip: _pinned ? 'Odepnij' : 'Przypnij',
            onPressed: () => setState(() => _pinned = !_pinned),
          ),
          // Kosz: dla istniejacej notatki -> do kosza,
          // dla nowej -> odrzuc bez zapisu
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip:
                widget.note != null ? 'Usun do kosza' : 'Odrzuc notatke',
            onPressed: widget.note != null ? _deleteNote : _discardNew,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Udostepnij',
            onPressed: _shareNote,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, 16 + MediaQuery.of(context).viewPadding.bottom + 24),
            children: [
              TextField(
                controller: _titleController,
                style: Theme.of(context).textTheme.titleLarge,
                decoration: const InputDecoration(
                    hintText: 'Tytul', border: InputBorder.none),
                textCapitalization: TextCapitalization.sentences,
              ),
              const Divider(),
              // Tryb tekstowy albo lista
              if (!_isList)
                TextField(
                  controller: _contentController,
                  maxLines: null,
                  minLines: 8,
                  decoration: const InputDecoration(
                      hintText: 'Tresc notatki...',
                      border: InputBorder.none),
                  textCapitalization: TextCapitalization.sentences,
                )
              else
                _buildListEditor(),
              const SizedBox(height: 16),

              // Przypomnienie (na gorze - najczesciej uzywane)
              _sectionCard(
                icon: Icons.notifications_outlined,
                title: 'Przypomnienie',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reminderText != null) ...[
                      Row(children: [
                        Expanded(
                            child: Text(reminderText,
                                style:
                                    Theme.of(context).textTheme.bodyLarge)),
                        IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Usun przypomnienie',
                            onPressed: _clearReminder),
                      ]),
                      const SizedBox(height: 8),
                    ],
                    FilledButton.tonalIcon(
                      onPressed: _pickReminder,
                      icon: const Icon(Icons.alarm_add),
                      label: Text(reminderText == null
                          ? 'Ustaw przypomnienie'
                          : 'Zmien termin'),
                    ),
                    // Opcja budzika - tylko gdy przypomnienie ustawione
                    if (reminderText != null) ...[
                      const SizedBox(height: 4),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(Icons.alarm,
                            color: _forceAlarm
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline),
                        title: const Text('Wybudzaj ekran'),
                        subtitle: const Text(
                            'Podswietla ekran i pokazuje powiadomienie na pelnym ekranie'),
                        value: _forceAlarm,
                        onChanged: (v) => setState(() => _forceAlarm = v),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Wybor koloru (zwijany)
              _collapsibleSection(
                icon: Icons.palette_outlined,
                title: 'Kolor',
                expanded: _colorExpanded,
                onToggle: () =>
                    setState(() => _colorExpanded = !_colorExpanded),
                subtitle: _colorIndex == 0
                    ? 'Domyslny'
                    : NoteColors.names[_colorIndex],
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(NoteColors.count, (i) {
                    final c = NoteColors.colorFor(i, brightness);
                    final selected = _colorIndex == i;
                    return GestureDetector(
                      onTap: () => setState(() => _colorIndex = i),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: c ??
                              Theme.of(context).colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                            width: selected ? 3 : 1,
                          ),
                        ),
                        child: selected
                            ? const Icon(Icons.check, size: 18)
                            : null,
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 12),

              // Wybor folderu (zwijany)
              _collapsibleSection(
                icon: Icons.folder_outlined,
                title: 'Folder',
                expanded: _folderExpanded,
                onToggle: () =>
                    setState(() => _folderExpanded = !_folderExpanded),
                subtitle: _folderName(),
                child: DropdownButton<int?>(
                  value: _folderId,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  hint: const Text('Bez folderu'),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('Bez folderu')),
                    ..._folders.map((f) => DropdownMenuItem<int?>(
                        value: f.id, child: Text(f.name))),
                  ],
                  onChanged: (v) => setState(() => _folderId = v),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  // Widok edycji listy (model Keep: ostatnia pozycja zawsze pusta)
  Widget _buildListEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(_items.length, (i) {
          final item = _items[i];
          final isLast = i == _items.length - 1;
          final isEmptyLast = isLast &&
              _itemControllers[i].text.trim().isEmpty &&
              !item.checked;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                // Ostatnia pusta pozycja ma "+" zamiast checkboxa
                if (isEmptyLast)
                  SizedBox(
                    width: 48,
                    child: Icon(Icons.add,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary),
                  )
                else
                  Checkbox(
                    value: item.checked,
                    onChanged: (_) => _toggleItem(i),
                  ),
                Expanded(
                  child: TextField(
                    controller: _itemControllers[i],
                    focusNode: _itemFocusNodes[i],
                    textInputAction: TextInputAction.next,
                    style: TextStyle(
                      decoration: item.checked
                          ? TextDecoration.lineThrough
                          : null,
                      color: item.checked
                          ? Theme.of(context).colorScheme.outline
                          : null,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: isEmptyLast ? 'Dodaj pozycje...' : null,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    // Zatwierdzenie -> przejscie do nastepnej pozycji
                    // (nowa pusta powstaje dopiero tutaj, nie przy pisaniu)
                    onSubmitted: (_) => _focusNext(i),
                  ),
                ),
                // Krzyzyk tylko dla niepustych pozycji
                if (!isEmptyLast)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _removeItem(i),
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          );
        }),
      ],
    );
  }

  // Przenosi focus do nastepnej pozycji; jesli brak - tworzy pusta
  void _focusNext(int index) {
    _syncItemsFromControllers();
    setState(() => _ensureTrailingEmpty());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final next = index + 1;
      if (next < _itemFocusNodes.length) {
        FocusScope.of(context).requestFocus(_itemFocusNodes[next]);
      }
    });
  }

  // Lekka wersja - tylko dodaje pusta na koniec jesli trzeba (bezpieczna w build)
  void _ensureTrailingEmpty() {
    final lastCtrl =
        _itemControllers.isNotEmpty ? _itemControllers.last : null;
    final last = _items.isNotEmpty ? _items.last : null;
    final lastEmpty = last != null &&
        lastCtrl != null &&
        lastCtrl.text.trim().isEmpty &&
        !last.checked;
    if (!lastEmpty) {
      _items.add(ListItem(text: ''));
      _itemControllers.add(TextEditingController());
      _itemFocusNodes.add(FocusNode());
    }
  }

  // Pelne porzadkowanie - usuwa puste ze srodka i dba o pusta na koncu.
  // Wolane poza faza budowania (focus, toggle), nie w samym build.
  void _cleanupEmptyItems() {
    for (int i = _items.length - 2; i >= 0; i--) {
      final empty =
          _itemControllers[i].text.trim().isEmpty && !_items[i].checked;
      if (empty) {
        _items.removeAt(i);
        _itemControllers.removeAt(i).dispose();
        _itemFocusNodes.removeAt(i).dispose();
      }
    }
    _ensureTrailingEmpty();
  }

  // Sekcja zawsze widoczna (np. przypomnienie)
  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  // Sekcja zwijana - tresc pojawia sie po klliknieciu naglowka
  Widget _collapsibleSection({
    required IconData icon,
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
    String? subtitle, // krotki opis widoczny gdy zwiniete
  }) {
    return Card(
      color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  if (subtitle != null && !expanded)
                    Flexible(
                      child: Text(
                        subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  Icon(expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: child,
            ),
        ],
      ),
    );
  }
}
