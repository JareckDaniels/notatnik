import 'package:flutter/material.dart';

// Bebnowy wybor godziny i minuty - przewijanie palcem gora/dol.
// Zwraca wybrana TimeOfDay przez Navigator.pop, albo null przy anulowaniu.
class WheelTimePicker extends StatefulWidget {
  final TimeOfDay initial;
  const WheelTimePicker({super.key, required this.initial});

  @override
  State<WheelTimePicker> createState() => _WheelTimePickerState();
}

class _WheelTimePickerState extends State<WheelTimePicker> {
  late int _hour;
  late int _minute;
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;

  @override
  void initState() {
    super.initState();
    _hour = widget.initial.hour;
    _minute = widget.initial.minute;
    _hourCtrl = FixedExtentScrollController(initialItem: _hour);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return AlertDialog(
      title: const Text('Wybierz godzine'),
      content: SizedBox(
        height: 200,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _wheel(
              controller: _hourCtrl,
              count: 24,
              selected: _hour,
              onChanged: (v) => setState(() => _hour = v),
              primary: primary,
              onSurface: onSurface,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(':',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: onSurface)),
            ),
            _wheel(
              controller: _minuteCtrl,
              count: 60,
              selected: _minute,
              onChanged: (v) => setState(() => _minute = v),
              primary: primary,
              onSurface: onSurface,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
              context, TimeOfDay(hour: _hour, minute: _minute)),
          child: const Text('OK'),
        ),
      ],
    );
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required int selected,
    required ValueChanged<int> onChanged,
    required Color primary,
    required Color onSurface,
  }) {
    return SizedBox(
      width: 70,
      height: 200,
      child: Stack(
        children: [
          // Podswietlenie srodkowego wiersza
          Center(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 48,
            perspective: 0.005,
            diameterRatio: 1.3,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: count,
              builder: (context, index) {
                final isSel = index == selected;
                return Center(
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: isSel ? 28 : 22,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      color: isSel ? primary : onSurface.withOpacity(0.5),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
