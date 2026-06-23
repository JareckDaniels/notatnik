import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../note.dart';
import '../folder.dart';
import '../database_helper.dart';
import '../notification_service.dart';
import '../note_colors.dart';

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
  int _colorIndex = 0;
  bool _pinned = false;
  int? _folderId;
  List<NoteFolder> _folders = [];

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
    _pinned = widget.note?.pinned ?? false;
    _folderId = widget.note?.folderId ?? widget.defaultFolderId;
    _loadFolders();
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

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      helpText: 'Wybierz godzine',
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

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      Navigator.pop(context, false);
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
      );
      await DatabaseHelper.instance.updateNote(updated);
      await NotificationService.instance.cancelReminder(widget.note!.id!);
      await _scheduleIfNeeded(widget.note!.id!, title, content);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _scheduleIfNeeded(int id, String title, String content) async {
    if (_reminder != null) {
      await NotificationService.instance.scheduleReminder(
        id: id,
        title: title.isEmpty ? 'Notatka' : title,
        body: content.isEmpty ? 'Przypomnienie' : content,
        dateTime: _reminder!,
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

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(widget.note == null ? 'Nowa notatka' : 'Edycja'),
        actions: [
          IconButton(
            icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined),
            tooltip: _pinned ? 'Odepnij' : 'Przypnij',
            onPressed: () => setState(() => _pinned = !_pinned),
          ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Zapisz',
            onPressed: _save,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _titleController,
                style: Theme.of(context).textTheme.titleLarge,
                decoration: const InputDecoration(
                    hintText: 'Tytul', border: InputBorder.none),
                textCapitalization: TextCapitalization.sentences,
              ),
              const Divider(),
              TextField(
                controller: _contentController,
                maxLines: null,
                minLines: 8,
                decoration: const InputDecoration(
                    hintText: 'Tresc notatki...', border: InputBorder.none),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),

              // Wybor koloru
              _sectionCard(
                icon: Icons.palette_outlined,
                title: 'Kolor',
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
                        child: i == 0
                            ? Icon(Icons.block,
                                size: 18,
                                color:
                                    Theme.of(context).colorScheme.outline)
                            : (selected
                                ? const Icon(Icons.check, size: 18)
                                : null),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 12),

              // Wybor folderu
              _sectionCard(
                icon: Icons.folder_outlined,
                title: 'Folder',
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

              const SizedBox(height: 12),

              // Przypomnienie
              _sectionCard(
                icon: Icons.notifications_outlined,
                title: 'Przypomnienie',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reminderText != null)
                      Row(children: [
                        Expanded(
                            child: Text(reminderText,
                                style:
                                    Theme.of(context).textTheme.bodyLarge)),
                        IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Usun przypomnienie',
                            onPressed: _clearReminder),
                      ])
                    else
                      Text('Brak - nacisnij przycisk ponizej',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline)),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: _pickReminder,
                      icon: const Icon(Icons.alarm_add),
                      label: Text(reminderText == null
                          ? 'Ustaw przypomnienie'
                          : 'Zmien termin'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
}
