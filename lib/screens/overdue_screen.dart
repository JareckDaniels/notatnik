import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../note.dart';
import '../database_helper.dart';
import '../note_colors.dart';
import 'note_edit_screen.dart';

// Lista notatek, ktorych termin przypomnienia juz minal
class OverdueScreen extends StatefulWidget {
  const OverdueScreen({super.key});

  @override
  State<OverdueScreen> createState() => _OverdueScreenState();
}

class _OverdueScreenState extends State<OverdueScreen> {
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final n = await DatabaseHelper.instance.getOverdueNotes();
    if (!mounted) return;
    setState(() {
      _notes = n;
      _loading = false;
    });
  }

  String _kiedy(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final teraz = DateTime.now();
    final roznica = teraz.difference(d);
    if (roznica.inDays >= 1) {
      final dni = roznica.inDays;
      return '$dni ${dni == 1 ? "dzień" : "dni"} temu · '
          '${DateFormat('d MMM, HH:mm', 'pl').format(d)}';
    }
    if (roznica.inHours >= 1) {
      final g = roznica.inHours;
      return '$g ${g == 1 ? "godzinę" : "godz."} temu · '
          '${DateFormat('HH:mm').format(d)}';
    }
    final m = roznica.inMinutes;
    return '$m min temu · ${DateFormat('HH:mm').format(d)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Po terminie'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 56,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 12),
                      Text(
                        'Brak zaległych przypomnień',
                        style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.outline),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(12, 12, 12,
                      12 + MediaQuery.of(context).viewPadding.bottom + 72),
                  itemCount: _notes.length,
                  itemBuilder: (_, i) => _kafelek(_notes[i]),
                ),
    );
  }

  Widget _kafelek(Note n) {
    final brightness = Theme.of(context).brightness;
    final kolor = NoteColors.colorFor(n.colorIndex, brightness);
    final maTytul = n.title.trim().isNotEmpty;
    final tresc = n.content.trim();
    final naglowek = maTytul ? n.title.trim() : tresc;

    return Card(
      color: kolor,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.notification_important,
            color: Theme.of(context).colorScheme.error),
        title: naglowek.isEmpty
            ? Text('Przypomnienie',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.outline))
            : Text(naglowek,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _kiedy(n.reminderAt!),
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.error),
          ),
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NoteEditScreen(note: n)),
          );
          _load();
        },
      ),
    );
  }
}
