import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../note.dart';
import '../database_helper.dart';
import '../note_colors.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final notes = await DatabaseHelper.instance.getTrash();
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  Future<void> _restore(Note note) async {
    if (note.id == null) return;
    await DatabaseHelper.instance.restoreFromTrash(note.id!);
    _load();
  }

  Future<void> _deletePermanently(Note note) async {
    if (note.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usunąć trwale?'),
        content: const Text('Tej notatki nie da się później odzyskać.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Anuluj')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Usuń trwale')),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteNotePermanently(note.id!);
      _load();
    }
  }

  Future<void> _emptyTrash() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Opróżnić cały kosz?'),
        content: const Text(
            'Wszystkie notatki z kosza zostaną trwale usunięte. Nie da się tego cofnąć.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Anuluj')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Opróżnij')),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.emptyTrash();
      _load();
    }
  }

  // Ile dni zostalo do automatycznego usuniecia
  int _daysLeft(Note note) {
    if (note.deletedAt == null) return DatabaseHelper.trashRetentionDays;
    final deleted = DateTime.fromMillisecondsSinceEpoch(note.deletedAt!);
    final purgeDate =
        deleted.add(const Duration(days: DatabaseHelper.trashRetentionDays));
    final left = purgeDate.difference(DateTime.now()).inDays;
    return left < 0 ? 0 : left;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kosz'),
        actions: [
          if (_notes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'Opróżnij kosz',
              onPressed: _emptyTrash,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline,
                          size: 72,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 12),
                      Text('Kosz jest pusty',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Notatki w koszu są usuwane automatycznie po '
                        '${DatabaseHelper.trashRetentionDays} dniach.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: ListView.builder(
                            padding: EdgeInsets.fromLTRB(12, 12, 12,
                                12 + MediaQuery.of(context).viewPadding.bottom + 72),
                            itemCount: _notes.length,
                            itemBuilder: (_, i) => _trashTile(_notes[i]),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _trashTile(Note note) {
    final brightness = Theme.of(context).brightness;
    final cardColor = NoteColors.colorFor(note.colorIndex, brightness);
    final daysLeft = _daysLeft(note);

    return Card(
      color: cardColor,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note.title.isNotEmpty)
              Text(note.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            if (note.content.isNotEmpty) ...[
              if (note.title.isNotEmpty) const SizedBox(height: 4),
              Text(note.content,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule,
                    size: 14, color: Theme.of(context).colorScheme.outline),
                const SizedBox(width: 4),
                Text(
                  daysLeft > 0
                      ? 'Usunięcie za $daysLeft dni'
                      : 'Usunięcie wkrótce',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _restore(note),
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('Przywróć'),
                ),
                IconButton(
                  onPressed: () => _deletePermanently(note),
                  icon: const Icon(Icons.delete_forever, size: 20),
                  tooltip: 'Usuń trwale',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
