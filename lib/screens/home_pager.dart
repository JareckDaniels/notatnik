import 'package:flutter/material.dart';
import '../settings_store.dart';
import 'folders_screen.dart';
import 'calendar_screen.dart';

// Dwa pulpity przesuwane w bok: notatki <-> kalendarz.
// Ktory jest pierwszy przy starcie, decyduje ustawienie.
class HomePager extends StatefulWidget {
  const HomePager({super.key});

  @override
  State<HomePager> createState() => _HomePagerState();
}

class _HomePagerState extends State<HomePager> {
  PageController? _controller;
  int _strona = 0;
  bool _gotowe = false;

  final _kalendarzKey = GlobalKey<CalendarScreenState>();

  @override
  void initState() {
    super.initState();
    _wczytajStart();
  }

  Future<void> _wczytajStart() async {
    final start = await SettingsStore.getStartPage();
    if (!mounted) return;
    setState(() {
      _strona = start;
      _controller = PageController(initialPage: start);
      _gotowe = true;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_gotowe) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _controller,
            onPageChanged: (i) {
              setState(() => _strona = i);
              // Wchodzac na kalendarz odswiez dane (notatki mogly sie zmienic)
              if (i == 1) _kalendarzKey.currentState?.load();
            },
            children: [
              const FoldersScreen(),
              CalendarScreen(key: _kalendarzKey),
            ],
          ),
          // Wskaznik pulpitow (kropki) na dole
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).viewPadding.bottom + 6,
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(2, (i) {
                  final aktywna = _strona == i;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: aktywna ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: aktywna
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
