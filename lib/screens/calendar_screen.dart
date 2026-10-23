import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../note.dart';
import '../database_helper.dart';
import '../note_colors.dart';
import '../settings_store.dart';
import 'note_edit_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  // Wszystkie notatki z przypomnieniem, pogrupowane po dniu
  Map<DateTime, List<Note>> _wgDnia = {};
  bool _loading = true;

  DateTime _widocznyMiesiac = DateTime.now();
  DateTime? _wybranyDzien;
  bool _widokTygodnia = false; // false = miesiac (domyslnie)

  @override
  void initState() {
    super.initState();
    _wybranyDzien = _tylkoData(DateTime.now());
    _wczytajWidok();
    load();
  }

  // Domyslny widok (miesiac/tydzien) z ustawien
  Future<void> _wczytajWidok() async {
    final v = await SettingsStore.getCalendarView();
    if (!mounted) return;
    setState(() => _widokTygodnia = v == 1);
  }

  // Publiczna, by rodzic mogl odswiezyc po zmianach w notatkach
  Future<void> load() async {
    final notes = await DatabaseHelper.instance.getNotesWithReminders();
    final mapa = <DateTime, List<Note>>{};
    for (final n in notes) {
      final d = _tylkoData(
          DateTime.fromMillisecondsSinceEpoch(n.reminderAt!));
      mapa.putIfAbsent(d, () => []).add(n);
    }
    if (!mounted) return;
    setState(() {
      _wgDnia = mapa;
      _loading = false;
    });
  }

  DateTime _tylkoData(DateTime d) => DateTime(d.year, d.month, d.day);

  // Dodawanie dni kalendarzowych przez konstruktor DateTime, zamiast przez
  // Duration(days: ...). To chroni kalendarz przed przesunieciami podczas
  // zmiany czasu letniego/zimowego (doba moze miec 23 lub 25 godzin).
  DateTime _dodajDni(DateTime d, int dni) =>
      DateTime(d.year, d.month, d.day + dni);

  // Pierwsza litera wielka (nazwy miesiecy/dni w polskim sa z malej)
  String _zWielkiej(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  List<Note> _notatkiDnia(DateTime dzien) => _wgDnia[_tylkoData(dzien)] ?? [];

  // Czy dzien ma jakies minione (przeterminowane) przypomnienie
  bool _maMinione(DateTime dzien) {
    final teraz = DateTime.now().millisecondsSinceEpoch;
    return _notatkiDnia(dzien).any((n) => n.reminderAt! < teraz);
  }

  // Tlo kratki dnia:
  // - blado czerwone, gdy jest choc jedno minione przypomnienie
  // - blado zielone, gdy sa przypomnienia (wszystkie przyszle)
  // - neutralne, gdy brak notatek
  // Wybrany dzien dostaje mocniejszy odcien.
  Color _tloDnia(DateTime dzien, bool wybrany) {
    final notatki = _notatkiDnia(dzien);
    final cs = Theme.of(context).colorScheme;

    if (notatki.isEmpty) {
      return wybrany
          ? cs.primaryContainer.withOpacity(0.55)
          : cs.surfaceContainerHighest.withOpacity(0.25);
    }
    if (_maMinione(dzien)) {
      return cs.error.withOpacity(wybrany ? 0.30 : 0.16);
    }
    // Zielony akcent dla nadchodzacych
    const zielen = Color(0xFF4CAF50);
    return zielen.withOpacity(wybrany ? 0.32 : 0.18);
  }

  void _poprzedni() {
    setState(() {
      if (_widokTygodnia) {
        _widocznyMiesiac = _dodajDni(_widocznyMiesiac, -7);
      } else {
        _widocznyMiesiac = DateTime(
            _widocznyMiesiac.year, _widocznyMiesiac.month - 1, 1);
      }
    });
  }

  void _nastepny() {
    setState(() {
      if (_widokTygodnia) {
        _widocznyMiesiac = _dodajDni(_widocznyMiesiac, 7);
      } else {
        _widocznyMiesiac = DateTime(
            _widocznyMiesiac.year, _widocznyMiesiac.month + 1, 1);
      }
    });
  }

  void _dzis() {
    setState(() {
      _widocznyMiesiac = DateTime.now();
      _wybranyDzien = _tylkoData(DateTime.now());
    });
  }

  // Lista dni do wyswietlenia w siatce (z dopelnieniem do pelnych tygodni)
  List<DateTime> _dniSiatki() {
    if (_widokTygodnia) {
      // Tydzien zawierajacy _widocznyMiesiac (pon-niedz)
      final d = _widocznyMiesiac;
      final poniedzialek = _dodajDni(d, -(d.weekday - 1));
      return List.generate(7, (i) => _dodajDni(poniedzialek, i));
    }
    // Pelny miesiac + dopelnienie
    final pierwszy =
        DateTime(_widocznyMiesiac.year, _widocznyMiesiac.month, 1);
    final startOffset = pierwszy.weekday - 1; // pon = 0
    final start = _dodajDni(pierwszy, -startOffset);
    // 6 tygodni = 42 dni (zawsze pokryje kazdy miesiac)
    final ile = 42;
    return List.generate(ile, (i) => _dodajDni(start, i));
  }

  @override
  Widget build(BuildContext context) {
    final dni = _dniSiatki();
    final wierszy = _widokTygodnia ? 1 : 6;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _widokTygodnia
              ? 'Tydzień'
              : _zWielkiej(
                  DateFormat('LLLL yyyy', 'pl').format(_widocznyMiesiac)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Dziś',
            onPressed: _dzis,
          ),
          IconButton(
            icon: Icon(_widokTygodnia
                ? Icons.calendar_view_month
                : Icons.calendar_view_week),
            tooltip: _widokTygodnia ? 'Widok miesiąca' : 'Widok tygodnia',
            onPressed: () =>
                setState(() => _widokTygodnia = !_widokTygodnia),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                // Kalendarz zajmuje 50% wysokosci, reszta = lista dnia
                final wysKalendarza = constraints.maxHeight * 0.50;
                return Column(
                  children: [
                    SizedBox(
                      height: wysKalendarza,
                      child: Column(
                        children: [
                          _pasekNawigacji(),
                          if (!_widokTygodnia) _naglowkiDni(),
                          Expanded(
                            child: _widokTygodnia
                                ? _listaTygodnia(dni)
                                : _siatka(dni, wierszy),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(child: _listaWybranegoDnia()),
                  ],
                );
              },
            ),
    );
  }

  Widget _pasekNawigacji() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _poprzedni,
          ),
          Text(
            _widokTygodnia
                ? '${DateFormat('d MMM', 'pl').format(_dniSiatki().first)} – '
                    '${DateFormat('d MMM yyyy', 'pl').format(_dniSiatki().last)}'
                : _zWielkiej(DateFormat('LLLL yyyy', 'pl')
                    .format(_widocznyMiesiac)),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _nastepny,
          ),
        ],
      ),
    );
  }

  Widget _naglowkiDni() {
    const dni = ['Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'So', 'Nd'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        children: dni
            .map((d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.outline),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // Widok tygodnia: 7 dni jeden pod drugim, dziela wysokosc po rowno
  // (zawsze mieszcza sie bez przewijania).
  Widget _listaTygodnia(List<DateTime> dni) {
    final dzisiaj = _tylkoData(DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Column(
        children: dni.map((dzien) {
          final notatki = _notatkiDnia(dzien);
          final wybrany = _wybranyDzien != null &&
              _tylkoData(_wybranyDzien!) == dzien;
          final jestDzis = dzien == dzisiaj;
          final nazwaDnia =
              _zWielkiej(DateFormat('EEE', 'pl').format(dzien));
          final tlo = _tloDnia(dzien, wybrany);

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _wybranyDzien = dzien),
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tlo,
                  borderRadius: BorderRadius.circular(10),
                  border: jestDzis
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5)
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Data po lewej (waska kolumna)
                    SizedBox(
                      width: 46,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${dzien.day}',
                            style: TextStyle(
                              fontSize: 17,
                              height: 1.1,
                              fontWeight: jestDzis
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: jestDzis
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                            ),
                          ),
                          Text(
                            nazwaDnia,
                            style: TextStyle(
                                fontSize: 10,
                                height: 1.1,
                                color:
                                    Theme.of(context).colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                    // Notatki po prawej: pierwsza (skrocona) + licznik reszty
                    Expanded(
                      child: notatki.isEmpty
                          ? const SizedBox.shrink()
                          : Row(
                              children: [
                                Expanded(
                                  child: _miniNotatka(notatki.first,
                                      duza: true, maxZnakow: 20),
                                ),
                                if (notatki.length > 1)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(left: 6),
                                    child: Text(
                                      '+${notatki.length - 1}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _siatka(List<DateTime> dni, int wierszy) {
    final dzisiaj = _tylkoData(DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: List.generate(wierszy, (w) {
          // Wiersze dziela dostepna wysokosc po rowno
          return Expanded(
            child: Row(
              children: List.generate(7, (k) {
                final idx = w * 7 + k;
                if (idx >= dni.length) return const Expanded(child: SizedBox());
                final dzien = dni[idx];
                final notatki = _notatkiDnia(dzien);
                final wMiesiacu = dzien.month == _widocznyMiesiac.month;
                final wybrany = _wybranyDzien != null &&
                    _tylkoData(_wybranyDzien!) == dzien;
                final jestDzis = dzien == dzisiaj;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _wybranyDzien = dzien),
                    child: Container(
                      margin: const EdgeInsets.all(1.5),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: _tloDnia(dzien, wybrany),
                        borderRadius: BorderRadius.circular(8),
                        border: jestDzis
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1.5)
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${dzien.day}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: jestDzis
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: wMiesiacu
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withOpacity(0.5),
                            ),
                          ),
                          // Pierwsza notatka (bardzo krotka) + licznik reszty.
                          // ClipRect pilnuje, by nic nie wyszlo poza kratke.
                          Expanded(
                            child: notatki.isEmpty
                                ? const SizedBox.shrink()
                                : ClipRect(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _miniNotatka(notatki.first,
                                            maxZnakow: 5),
                                        if (notatki.length > 1)
                                          Text(
                                            '+${notatki.length - 1}',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 8,
                                                height: 1.1,
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .outline),
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
              }),
            ),
          );
        }),
      ),
    );
  }

  // Malutki pasek z tytulem (lub poczatkiem tresci) notatki.
  // Ma wyrazne tlo i obwodke, zeby nie zlewac sie z kratka dnia.
  Widget _miniNotatka(Note n, {bool duza = false, int? maxZnakow}) {
    final brightness = Theme.of(context).brightness;
    final wlasnyKolor = NoteColors.colorFor(n.colorIndex, brightness);
    final baza = wlasnyKolor ??
        Theme.of(context).colorScheme.primaryContainer;
    var tekst = n.title.trim().isNotEmpty
        ? n.title.trim()
        : n.content.trim().replaceAll('\n', ' ');
    if (tekst.isEmpty) tekst = 'Przypomnienie';
    // Obciecie do zadanej dlugosci, by nie rozpychalo kratki
    if (maxZnakow != null && tekst.length > maxZnakow) {
      tekst = '${tekst.substring(0, maxZnakow)}…';
    }

    return Container(
      margin: EdgeInsets.only(bottom: duza ? 0 : 1),
      padding: EdgeInsets.symmetric(
          horizontal: duza ? 6 : 3, vertical: duza ? 3 : 1),
      decoration: BoxDecoration(
        color: baza,
        borderRadius: BorderRadius.circular(duza ? 6 : 4),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.35),
          width: 0.6,
        ),
      ),
      child: Text(
        tekst,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: duza ? 12.5 : 8,
          height: 1.15,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _listaWybranegoDnia() {
    if (_wybranyDzien == null) {
      return const Center(child: Text('Wybierz dzień'));
    }
    final notatki = _notatkiDnia(_wybranyDzien!);
    final naglowek =
        _zWielkiej(DateFormat('EEEE, d MMMM', 'pl').format(_wybranyDzien!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Text(
            naglowek,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: notatki.isEmpty
              ? Center(
                  child: Text(
                    'Brak przypomnień tego dnia',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.outline),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(12, 0, 12,
                      12 + MediaQuery.of(context).viewPadding.bottom + 72),
                  itemCount: notatki.length,
                  itemBuilder: (_, i) => _kafelekNotatki(notatki[i]),
                ),
        ),
      ],
    );
  }

  Widget _kafelekNotatki(Note n) {
    final brightness = Theme.of(context).brightness;
    final kolor = NoteColors.colorFor(n.colorIndex, brightness);
    final godzina = DateFormat('HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(n.reminderAt!));
    final minelo =
        n.reminderAt! < DateTime.now().millisecondsSinceEpoch;

    // Gdy notatka nie ma tytulu, jako naglowek sluzy jej tresc
    // (zamiast rzucajacego sie w oczy "(bez tytulu)").
    final maTytul = n.title.trim().isNotEmpty;
    final tresc = n.content.trim();
    final naglowek = maTytul ? n.title.trim() : tresc;
    final podtytul = maTytul ? tresc : '';

    return Card(
      color: kolor,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              minelo
                  ? Icons.notification_important
                  : Icons.notifications_active,
              size: 18,
              color: minelo
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 2),
            Text(godzina,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: minelo
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary)),
          ],
        ),
        title: naglowek.isEmpty
            ? Text(
                'Przypomnienie',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.outline),
              )
            : Text(
                naglowek,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
        subtitle: podtytul.isEmpty
            ? null
            : Text(
                podtytul,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
        onTap: () async {
          final zmiana = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => NoteEditScreen(note: n)),
          );
          if (zmiana == true) load();
        },
      ),
    );
  }
}
