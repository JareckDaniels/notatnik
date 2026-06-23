import 'package:flutter/material.dart';
import '../notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ReminderStyle? _style;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ustawienia')),
      body: _style == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      child: Text(
                        'Rodzaj przypomnienia',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    _buildOption(
                      ReminderStyle.soundNotification,
                      'Powiadomienie z dźwiękiem',
                      'Standardowe powiadomienie z dźwiękiem',
                      Icons.notifications_active,
                    ),
                    _buildOption(
                      ReminderStyle.silentNotification,
                      'Powiadomienie ciche',
                      'Powiadomienie bez dźwięku',
                      Icons.notifications_off,
                    ),
                    _buildOption(
                      ReminderStyle.fullScreenAlarm,
                      'Pełnoekranowy alarm',
                      'Alarm na cały ekran, jak budzik',
                      Icons.alarm,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Zmiana dotyczy przypomnień ustawianych po '
                                'jej zapisaniu.',
                                style:
                                    Theme.of(context).textTheme.bodySmall,
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

  Widget _buildOption(
    ReminderStyle style,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final selected = _style == style;
    return Card(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: RadioListTile<ReminderStyle>(
        value: style,
        groupValue: _style,
        onChanged: (v) {
          if (v != null) _setStyle(v);
        },
        title: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: 28, top: 2),
          child: Text(subtitle),
        ),
      ),
    );
  }
}
