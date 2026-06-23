import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../note.dart';
import '../database_helper.dart';
import '../notification_service.dart';

class NoteEditScreen extends StatefulWidget {
  final Note? note;
  const NoteEditScreen({super.key, this.note});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  DateTime? _reminder;

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
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // Wybór daty, a następnie godziny przypomnienia
  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final initialDate = _reminder ?? now.add(const Duration(hours: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 10)),
      helpText: 'Wybierz dzień przypomnienia',
    );
    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      helpText: 'Wybierz godzinę',
    );
    if (time == null) return;

    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (picked.isBefore(DateTime.now())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wybierz datę w przyszłości')),
      );
      return;
    }

    setState(() => _reminder = picked);
  }

  void _clearReminder() {
    setState(() => _reminder = null);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      // Nic do zapisania - po prostu wróć
      Navigator.pop(context, false);
      return;
    }

    final reminderMs = _reminder?.millisecondsSinceEpoch;

    if (widget.note == null) {
      // Nowa notatka
      final note = Note(
        title: title,
        content: content,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        reminderAt: reminderMs,
      );
      final id = await DatabaseHelper.instance.insertNote(note);
      await _scheduleIfNeeded(id, title, content);
    } else {
      // Edycja istniejącej
      final updated = widget.note!.copyWith(
        title: title,
        content: content,
        reminderAt: reminderMs,
        clearReminder: reminderMs == null,
      );
      await DatabaseHelper.instance.updateNote(updated);
      // Najpierw anuluj stare przypomnienie, potem ustaw nowe
      await NotificationService.instance.cancelReminder(widget.note!.id!);
      await _scheduleIfNeeded(widget.note!.id!, title, content);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _scheduleIfNeeded(
      int id, String title, String content) async {
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
    final reminderText = _reminder != null
        ? DateFormat('dd.MM.yyyy, HH:mm').format(_reminder!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'Nowa notatka' : 'Edycja'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Zapisz',
            onPressed: _save,
          ),
        ],
      ),
      body: Center(
        // Ograniczamy szerokość na dużych ekranach (czytelność)
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _titleController,
                style: Theme.of(context).textTheme.titleLarge,
                decoration: const InputDecoration(
                  hintText: 'Tytuł',
                  border: InputBorder.none,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const Divider(),
              TextField(
                controller: _contentController,
                maxLines: null,
                minLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Treść notatki...',
                  border: InputBorder.none,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),
              // Sekcja przypomnienia
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.notifications_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Przypomnienie',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (reminderText != null)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                reminderText,
                                style:
                                    Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: 'Usuń przypomnienie',
                              onPressed: _clearReminder,
                            ),
                          ],
                        )
                      else
                        Text(
                          'Brak — naciśnij przycisk poniżej',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color:
                                    Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: _pickReminder,
                        icon: const Icon(Icons.alarm_add),
                        label: Text(
                          reminderText == null
                              ? 'Ustaw przypomnienie'
                              : 'Zmień termin',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
