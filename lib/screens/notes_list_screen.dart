import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import '../note.dart';
import '../database_helper.dart';
import '../notification_service.dart';
import '../note_colors.dart';
import 'note_edit_screen.dart';

class NotesListScreen extends StatefulWidget {
  final int? folderId;
  final bool noFolderOnly;
  final String screenTitle;

  const NotesListScreen({
    super.key,
    this.folderId,
    this.noFolderOnly = false,
    this.screenTitle = 'Notatki',
  });

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
    List<Note> notes;
    if (widget.noFolderOnly) {
      notes = await DatabaseHelper.instance.getNotes(noFolder: true);
    } else if (widget.folderId != null) {
      notes = await DatabaseHelper.instance.getNotes(folderId: widget.folderId);
    } else {
      notes = await DatabaseHelper.instance.getAllNotes();
    }
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  Future<void> _openEditor({Note? note}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditScreen(
          note: note,
          defaultFolderId: widget.folderId,
        ),
      ),
    );
    if (changed == true) _loadNotes();
  }

  Future<void> _deleteNote(Note note) async {
    if (note.id == null) return;
    await NotificationService.instance.cancelReminder(note.id!);
    await DatabaseHelper.instance.deleteNote(note.id!);
    _loadNotes();
  }

  Future<void> _togglePin(Note note) async {
    final updated = note.copyWith(pinned: !note.pinned);
    await DatabaseHelper.instance.updateNote(updated);
    _loadNotes();
  }

  int _columnsForWidth(double width) {
    if (width >= 1200) return 4;
    if (width >= 840) return 3;
    if (width >= 560) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.screenTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? _buildEmptyState(context)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = _columnsForWidth(constraints.maxWidth);
                    // Masonry: kazda karta ma wysokosc dopasowana do tresci
                    // (krotka notatka = niska karta), z limitem 5 linii w karcie.
                    return MasonryGridView.count(
                      padding: const EdgeInsets.all(12),
                      crossAxisCount: columns,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      itemCount: _notes.length,
                      itemBuilder: (context, index) =>
                          _buildNoteCard(_notes[index]),
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
          Icon(Icons.note_alt_outlined,
              size: 80, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text('Brak notatek',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Dodaj pierwsza, naciskajac "Nowa"',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    );
  }

  Widget _buildNoteCard(Note note) {
    final brightness = Theme.of(context).brightness;
    final cardColor = NoteColors.colorFor(note.colorIndex, brightness);
    final hasReminder = note.reminderAt != null;
    final reminderText = hasReminder
        ? DateFormat('dd.MM.yyyy HH:mm')
            .format(DateTime.fromMillisecondsSinceEpoch(note.reminderAt!))
        : null;

    return Card(
      color: cardColor,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _openEditor(note: note),
        child: Padding(
          padding: const EdgeInsets.all(14),
          // Kolumna kurczy sie do wysokosci tresci (mainAxisSize.min)
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (note.pinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.push_pin,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                  Expanded(
                    child: Text(
                      note.title.isEmpty ? '(bez tytulu)' : note.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Mniejszy obszar dotyku menu, by nie zawyzac wysokosci
                  SizedBox(
                    height: 28,
                    width: 28,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert, size: 20),
                      onSelected: (value) {
                        if (value == 'delete') _deleteNote(note);
                        if (value == 'pin') _togglePin(note);
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
                            Text('Usun'),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (note.content.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  note.content,
                  style: Theme.of(context).textTheme.bodyMedium,
                  // Pokazuje maksymalnie 5 linijek, reszte ucina wielokropkiem
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (hasReminder) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.notifications_active,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        reminderText!,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                                color:
                                    Theme.of(context).colorScheme.primary),
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
