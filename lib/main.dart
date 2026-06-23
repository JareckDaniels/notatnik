import 'package:flutter/material.dart';
import 'notification_service.dart';
import 'screens/notes_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  await NotificationService.instance.requestPermissions();
  runApp(const NotatkiApp());
}

class NotatkiApp extends StatelessWidget {
  const NotatkiApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Schemat kolorów oparty na jednym kolorze bazowym
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
      home: const NotesListScreen(),
    );
  }
}
