import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'notification_service.dart';
import 'database_helper.dart';
import 'screens/folders_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Dane formatowania dat dla jezyka polskiego (nazwy dni, miesiecy)
  await initializeDateFormatting('pl', null);
  await NotificationService.instance.init();
  await NotificationService.instance.requestPermissions();
  // Czyszczenie kosza: usuwa notatki starsze niz 30 dni
  await DatabaseHelper.instance.purgeOldTrash();
  runApp(const NotatkiApp());
}

class NotatkiApp extends StatelessWidget {
  const NotatkiApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF4A6FA5);

    return MaterialApp(
      title: 'Notatki',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),
      themeMode: ThemeMode.system,
      // Jezyk polski - m.in. kalendarz i zegar po polsku
      locale: const Locale('pl', 'PL'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pl', 'PL'),
        Locale('en', 'US'),
      ],
      home: const FoldersScreen(),
    );
  }
}
