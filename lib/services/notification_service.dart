import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();
  final plugin = FlutterLocalNotificationsPlugin();
  bool initialized = false;

  Future<void> initialize() async {
    if (initialized) return;
    tz.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {}
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final settings = InitializationSettings(android: android);
    await plugin.initialize(settings: settings);
    initialized = true;
  }

  Future<void> requestPermission() async {
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  int _id(String id) => id.hashCode & 0x7fffffff;

  Future<void> scheduleNoteReminder({required String noteId, required String title, required DateTime when}) async {
    await initialize();
    await requestPermission();
    final target = tz.TZDateTime.from(when, tz.local);
    if (target.isBefore(tz.TZDateTime.now(tz.local))) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails('note_reminders', 'یادآوری یادداشت‌ها', channelDescription: 'یادآوری یادداشت‌های آبجی بزرگ و داداش کوچیکه', importance: Importance.high, priority: Priority.high),
    );
    await plugin.zonedSchedule(id: _id(noteId), title: 'یادآوری یادداشت ❤️', body: title.isEmpty ? 'یادت نرود به یادداشتت سر بزنی.' : title, scheduledDate: target, notificationDetails: details, androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, payload: noteId);
  }

  Future<void> cancelNoteReminder(String noteId) async { await initialize(); await plugin.cancel(id: _id(noteId)); }
}
