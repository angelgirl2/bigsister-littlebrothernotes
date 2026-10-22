import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  Future<void> showIncomingLetter({required String id, required String title}) async {
    try {
      await initialize();
      await requestPermission();
      const details = NotificationDetails(android: AndroidNotificationDetails(
        'letters', 'نامه‌های جدید',
        channelDescription: 'اعلان نامه‌های دفتر مشترک',
        importance: Importance.max, priority: Priority.high, playSound: true,
      ));
      await plugin.show(id: _id('letter:$id'), title: 'نامهٔ جدید ❤️',
        body: title.trim().isEmpty ? 'یک نامهٔ تازه دریافت کردی.' : title.trim(),
        notificationDetails: details, payload: 'letter:$id');
    } catch (_) {}
  }

  Future<void> showIncomingCall({required bool video}) async {
    try {
      await initialize();
      await requestPermission();
      const details = NotificationDetails(android: AndroidNotificationDetails(
        'incoming_calls', 'تماس‌های ورودی',
        channelDescription: 'اعلان تماس صوتی و تصویری',
        importance: Importance.max, priority: Priority.max, playSound: true,
        category: AndroidNotificationCategory.call, ongoing: true,
      ));
      await plugin.show(id: 2147483000, title: video ? 'تماس تصویری ورودی' : 'تماس صوتی ورودی',
        body: 'برای پاسخ، برنامه را باز کن.', notificationDetails: details, payload: 'incoming_call');
    } catch (_) {}
  }

  Future<void> cancelIncomingCall() async {
    try { await initialize(); await plugin.cancel(id: 2147483000); } catch (_) {}
  }

  Future<void> showMissedCall({required String callId, required bool video}) async {
    try {
      await initialize();
      await requestPermission();
      final prefs = await SharedPreferences.getInstance();
      const key = 'big_sister_missed_call_notified_v1';
      final seen = (prefs.getStringList(key) ?? <String>[]).toSet();
      if (seen.contains(callId)) return;
      const details = NotificationDetails(android: AndroidNotificationDetails(
        'missed_calls', 'تماس‌های ازدست‌رفته',
        channelDescription: 'تماس‌های بی‌پاسخ بین دو عضو دفتر مشترک',
        importance: Importance.max, priority: Priority.high, playSound: true,
      ));
      await plugin.show(
        id: _id('missed:$callId'),
        title: video ? 'تماس تصویری ازدست‌رفته' : 'تماس صوتی ازدست‌رفته',
        body: 'از طرف مقابل یک تماس بی‌پاسخ داری.',
        notificationDetails: details,
        payload: 'call:$callId',
      );
      seen.add(callId);
      await prefs.setStringList(key, seen.toList().reversed.take(200).toList().reversed.toList());
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
