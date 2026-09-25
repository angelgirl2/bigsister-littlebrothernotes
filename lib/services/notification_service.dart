import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../cloud/chat_models.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  bool initialized = false;
  bool _permissionRequested = false;

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
    if (_permissionRequested) return;
    await initialize();
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    _permissionRequested = true;
  }

  int _id(String id) => id.hashCode & 0x7fffffff;

  Future<void> showIncomingChat(ChatMessage message) async {
    try {
      await initialize();
      await requestPermission();
      final preview = message.body.trim().isEmpty
          ? switch (message.type) {
              'image' => 'یک عکس جدید فرستاده شد.',
              'video' => 'یک ویدیو جدید فرستاده شد.',
              'audio' => 'یک پیام صوتی جدید فرستاده شد.',
              _ => 'یک فایل جدید فرستاده شد.',
            }
          : message.body.trim().replaceAll('\n', ' ');
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'chat_messages',
          'پیام‌های جدید',
          channelDescription: 'اعلان پیام‌های جدید دفتر مشترک',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      );
      await plugin.show(
        id: _id(message.id),
        title: 'پیام جدید ❤️',
        body: preview.length > 160 ? '${preview.substring(0, 160)}…' : preview,
        notificationDetails: details,
        payload: message.id,
      );
    } catch (_) {}
  }

  Future<void> scheduleNoteReminder({required String noteId, required String title, required DateTime when}) async {
    await initialize();
    await requestPermission();
    final target = tz.TZDateTime.from(when.toLocal(), tz.local);
    if (target.isBefore(tz.TZDateTime.now(tz.local))) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'note_reminders',
        'یادآوری یادداشت‌ها',
        channelDescription: 'یادآوری یادداشت‌های آبجی بزرگ و داداش کوچیکه',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await plugin.zonedSchedule(
      id: _id(noteId),
      title: 'یادآوری یادداشت ❤️',
      body: title.isEmpty ? 'یادت نرود به یادداشتت سر بزنی.' : title,
      scheduledDate: target,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: noteId,
    );
  }

  Future<void> cancelNoteReminder(String noteId) async {
    await initialize();
    await plugin.cancel(id: _id(noteId));
  }
}
