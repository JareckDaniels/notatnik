import 'package:flutter/material.dart';
import '../notification_service.dart';
import '../backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ReminderStyle? _style;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadStyle();
  }

  Future<void> _loadStyle() async {
    final style = await NotificationService.instance.getReminderStyle();
    setState(() => _style = style);
  }

  Future<void> _setStyle(ReminderStyle style) async {
    await NotificationService.instance.setReminderStyle(style);
    setState(() => _style = style);
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      await BackupService.exportBackup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Blad eksportu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportToFolder() async {
    setState(() => _busy = true);
    try {
      final path = await BackupService.exportToFolder();
      if (mounted) {
        if (path == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Anulowano zapis')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Zapisano: $path')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Blad zapisu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    // Ostrzezenie: import nadpisuje obecne dane
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Importowac kopie?'),
        content: const Text(
            'Import zastapi WSZYSTKIE obecne notatki i foldery danymi z pliku. '
            'Tej operacji nie da sie cofnac. Kontynuowac?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Anuluj')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Importuj')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    final result = await BackupService.importBackup();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ustawienia')),
      body: _style == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: Text('Rodzaj przypomnienia',
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                        ),
                        _buildOption(
                            ReminderStyle.soundNotification,
                            'Powiadomienie z dzwiekiem',
                            'Standardowe powiadomienie z dzwiekiem',
                            Icons.notifications_active),
                        _buildOption(
                            ReminderStyle.silentNotification,
                            'Powiadomienie ciche',
                            'Powiadomienie bez dzwieku',
                            Icons.notifications_off),
                        _buildOption(
                            ReminderStyle.fullScreenAlarm,
                            'Pelnoekranowy alarm',
                            'Alarm na caly ekran, jak budzik',
                            Icons.alarm),

                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: Text('Kopia zapasowa',
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                        ),
                        Card(
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.upload_file),
                                title: const Text('Eksportuj (wyslij)'),
                                subtitle: const Text(
                                    'Udostepnij plik kopii (mail, dysk, komunikator)'),
                                onTap: _busy ? null : _export,
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.folder_open),
                                title: const Text('Zapisz do folderu'),
                                subtitle: const Text(
                                    'Zapisz plik kopii w pamieci telefonu'),
                                onTap: _busy ? null : _exportToFolder,
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.download),
                                title: const Text('Importuj notatki'),
                                subtitle: const Text(
                                    'Wczytaj kopie z pliku (zastepuje obecne)'),
                                onTap: _busy ? null : _import,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                        Card(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(children: [
                              Icon(Icons.info_outline,
                                  color:
                                      Theme.of(context).colorScheme.outline),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Kopie warto zrobic przed zmiana telefonu. '
                                  'Plik mozesz wyslac sobie mailem lub zapisac na dysku.',
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_busy)
                  Container(
                    color: Colors.black26,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }

  Widget _buildOption(
      ReminderStyle style, String title, String subtitle, IconData icon) {
    final selected = _style == style;
    return Card(
      color:
          selected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: RadioListTile<ReminderStyle>(
        value: style,
        groupValue: _style,
        onChanged: (v) {
          if (v != null) _setStyle(v);
        },
        title: Row(children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ]),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: 28, top: 2),
          child: Text(subtitle),
        ),
      ),
    );
  }
}
