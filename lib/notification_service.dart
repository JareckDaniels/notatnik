import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:shared_preferences/shared_preferences.dart';

// Typy przypomnień, które użytkownik wybiera w ustawieniach
enum ReminderStyle {
  soundNotification, // powiadomienie + dźwięk
  silentNotification, // powiadomienie ciche
  fullScreenAlarm, // pełnoekranowy alarm jak budzik
}

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  NotificationService._init();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _prefKey = 'reminder_style';

  // ID notatki z ostatnio klikntego powiadomienia (do otwarcia po starcie)
  static int? pendingNoteId;

  // Callback wywolywany gdy uzytkownik tapnie powiadomienie przy dzialajacej apce
  static void Function()? _onTapCallback;
  static void setOnNotificationTap(void Function() cb) {
    _onTapCallback = cb;
  }

  // Inicjalizacja - wywoływana raz przy starcie aplikacji
  Future<void> init() async {
    tzdata.initializeTimeZones();
    // Ustawiamy strefę na podstawie offsetu urządzenia
    tz.setLocalLocation(tz.getLocation(await _resolveTimeZone()));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Tapniecie w powiadomienie gdy apka dziala - zapisz ID notatki
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          pendingNoteId = int.tryParse(payload);
          _onTapCallback?.call();
        }
      },
    );

    // Sprawdz, czy apka zostala uruchomiona przez tapniecie w powiadomienie
    final launchDetails =
        await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        pendingNoteId = int.tryParse(payload);
      }
    }

    // Tworzymy kanały powiadomień (Android 8+)
    await _createChannels();
  }

  // Próbujemy odgadnąć strefę; fallback na Warszawę
  Future<String> _resolveTimeZone() async {
    try {
      return 'Europe/Warsaw';
    } catch (_) {
      return 'Europe/Warsaw';
    }
  }

  Future<void> _createChannels() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // Kanał: powiadomienie z dźwiękiem
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'reminder_sound',
        'Przypomnienia (dźwięk)',
        description: 'Przypomnienia z dźwiękiem',
        importance: Importance.high,
        playSound: true,
      ),
    );

    // Kanał: ciche powiadomienie
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'reminder_silent',
        'Przypomnienia (ciche)',
        description: 'Ciche przypomnienia',
        importance: Importance.defaultImportance,
        playSound: false,
      ),
    );

    // Kanał: pełnoekranowy alarm
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'reminder_alarm',
        'Przypomnienia (alarm)',
        description: 'Pełnoekranowe alarmy',
        importance: Importance.max,
        playSound: true,
      ),
    );
  }

  // Prośba o uprawnienia (Android 13+ powiadomienia, 12+ dokładne alarmy)
  Future<void> requestPermissions() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    await androidPlugin.requestNotificationsPermission();
    await androidPlugin.requestExactAlarmsPermission();
  }

  // Odczyt wybranego stylu przypomnienia
  Future<ReminderStyle> getReminderStyle() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_prefKey) ?? 0;
    return ReminderStyle.values[index];
  }

  // Zapis wybranego stylu przypomnienia
  Future<void> setReminderStyle(ReminderStyle style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, style.index);
  }

  // Zaplanowanie przypomnienia
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
  }) async {
    final style = await getReminderStyle();

    String channelId;
    Importance importance;
    Priority priority;
    bool playSound;
    bool fullScreen;

    switch (style) {
      case ReminderStyle.soundNotification:
        channelId = 'reminder_sound';
        importance = Importance.high;
        priority = Priority.high;
        playSound = true;
        fullScreen = false;
        break;
      case ReminderStyle.silentNotification:
        channelId = 'reminder_silent';
        importance = Importance.defaultImportance;
        priority = Priority.defaultPriority;
        playSound = false;
        fullScreen = false;
        break;
      case ReminderStyle.fullScreenAlarm:
        channelId = 'reminder_alarm';
        importance = Importance.max;
        priority = Priority.max;
        playSound = true;
        fullScreen = true;
        break;
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      'Przypomnienia',
      channelDescription: 'Przypomnienia z notatek',
      importance: importance,
      priority: priority,
      playSound: playSound,
      fullScreenIntent: fullScreen,
      category: fullScreen ? AndroidNotificationCategory.alarm : null,
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id,
      title.isEmpty ? 'Przypomnienie' : title,
      body,
      tz.TZDateTime.from(dateTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: '$id', // ID notatki - do otwarcia po tapnieciu
    );
  }

  // Anulowanie przypomnienia
  Future<void> cancelReminder(int id) async {
    await _plugin.cancel(id);
  }
}
