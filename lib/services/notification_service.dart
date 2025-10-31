import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications (Android/iOS) with time-zone aware scheduling.
class NotificationService {
  NotificationService();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'appointments_channel';
  static const _channelName = 'Aftaler';
  static const _channelDesc = 'Påmindelser for aftaler og betalinger';

  /// Call once after runApp (e.g., from AppBootstrap initState)
  Future<void> init() async {
    if (_initialized) return;

    // Timezone init
    tz.initializeTimeZones();
    final local = tz.getLocation(DateTime.now().timeZoneName);
    tz.setLocalLocation(local);

    // Android init
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS init
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: darwinInit),
    );

    // Ensure Android channel
    const androidDetails = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidDetails);

    _initialized = true;
  }

  /// Ask runtime notification permission (iOS + Android 13+).
  Future<void> requestPermissionIfNeeded() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosPlugin?.requestPermissions(alert: true, sound: true, badge: true);
  }

  /// Stable int id from a string (e.g., appointmentId + tag).
  int stableId(String key) {
    // Simple deterministic hash (fits 32-bit int)
    return key.codeUnits.fold<int>(0, (p, c) => (p * 31 + c) & 0x7fffffff);
  }

  /// Schedules a notification at [whenLocal]. If [whenLocal] is in the past, skip.
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime whenLocal,
    String? payload,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    final ts = tz.TZDateTime.from(whenLocal, tz.local);
    if (!ts.isAfter(now)) return;

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      ts,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  /// Cancel by id
  Future<void> cancel(int id) => _plugin.cancel(id);

  /// Convenience: schedule “2 hours before” if appointment is today.
  Future<void> scheduleSameDayTwoHoursBefore({
    required String appointmentId,
    required DateTime appointmentDateTime, // local
    required String title,
    required String body,
  }) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    if (appointmentDateTime.isBefore(start) ||
        !appointmentDateTime.isBefore(end)) {
      // Not today → skip
      return;
    }
    final trigger = appointmentDateTime.subtract(const Duration(hours: 2));
    final id = stableId('appt-$appointmentId-2h');
    await scheduleAt(id: id, title: title, body: body, whenLocal: trigger);
  }

  /// Example: schedule payment reminder today at 10:00 if payDate is today.
  Future<void> schedulePaymentReminderToday({
    required String appointmentId,
    required DateTime? payDate, // local date-only semantics expected
    String title = 'Betaling forfalden',
    required String body,
    int hour = 10,
  }) async {
    if (payDate == null) return;
    final now = DateTime.now();
    final isSameDay =
        (payDate.year == now.year &&
        payDate.month == now.month &&
        payDate.day == now.day);
    if (!isSameDay) return;

    final when = DateTime(now.year, now.month, now.day, hour);
    final id = stableId('pay-$appointmentId-$hour');
    await scheduleAt(id: id, title: title, body: body, whenLocal: when);
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
