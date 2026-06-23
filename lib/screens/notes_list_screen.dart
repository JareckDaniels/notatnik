import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../note.dart';
import '../database_helper.dart';
import '../notification_service.dart';
import 'note_edit_screen.dart';
import 'settings_screen.dart';

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _loading = true);
    final notes = await DatabaseHelper.instance.getAllNotes();
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  Future<void> _openEditor({Note? note}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NoteEditScreen(note: note)),
    );
    if (changed == true) {
      _loadNotes();
    }
  }

  Future<void> _deleteNote(Note note) async {
    if (note.id == null) return;
    // Anuluj ewentualne przypomnienie
    await NotificationService.instance.cancelReminder(note.id!);
    await DatabaseHelper.instance.deleteNote(note.id!);
    _loadNotes();
  }

  // Liczba kolumn zależna od szerokości ekranu (responsywność)
  int _columnsForWidth(double width) {
    if (width >= 1200) return 4;
    if (width >= 840) return 3;
    if (width >= 560) return 2;
    return 1;
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? _buildEmptyState(context)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = _columnsForWidth(constraints.maxWidth);
                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: _notes.length,
                      itemBuilder: (context, index) {
                        return _buildNoteCard(_notes[index]);
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Nowa'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_alt_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Brak notatek',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Dodaj pierwszą, naciskając „Nowa”',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(Note note) {
    final hasReminder = note.reminderAt != null;
    final reminderText = hasReminder
        ? DateFormat('dd.MM.yyyy HH:mm')
            .format(DateTime.fromMillisecondsSinceEpoch(note.reminderAt!))
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openEditor(note: note),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title.isEmpty ? '(bez tytułu)' : note.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (value) {
                      if (value == 'delete') _deleteNote(note);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 20),
                            SizedBox(width: 8),
                            Text('Usuń'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  note.content,
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.fade,
                ),
              ),
              if (hasReminder) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.notifications_active,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        reminderText!,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
