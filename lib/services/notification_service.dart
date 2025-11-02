import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _enabled = true;
  bool get enabled => _enabled;

  static const _channelId = 'appointments_channel';
  static const _channelName = 'Aftaler';
  static const _channelDesc = 'Påmindelser for aftaler og betalinger';
  Future<void> cancel(int id) => _plugin.cancel(id);
  Future<void> cancelAll() => _plugin.cancelAll();

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    await _setLocalTimeZone();

    // 2) Plugin init
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: darwinInit),
    );

    // 3) Ensure Android channel exists
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

  Future<void> applyEnabled(bool enabled) async {
    _enabled = enabled;
    if (!enabled) await cancelAll();
  }

  Future<void> _setLocalTimeZone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();

      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      try {
        tz.setLocalLocation(tz.getLocation('Europe/Copenhagen'));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    }
  }

  Future<bool> requestAllIfNeeded() async {
    await requestPermissionIfNeeded();
    await requestExactAlarmIfNeeded();

    return areEnabled();
  }

  Future<void> requestPermissionIfNeeded() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await ios?.requestPermissions(alert: true, sound: true, badge: true);
  }

  Future<void> requestExactAlarmIfNeeded() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestExactAlarmsPermission();
  }

  int stableId(String key) =>
      key.codeUnits.fold<int>(0, (p, c) => (p * 31 + c) & 0x7fffffff);

  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime whenLocal,
    String? payload,
  }) async {
    if (!_enabled) {
      return;
    }

    final ts = tz.TZDateTime.from(whenLocal, tz.local);

    if (!ts.isAfter(tz.TZDateTime.now(tz.local))) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        ts,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } on PlatformException catch (e) {
      final notPermitted = e.code == 'exact_alarms_not_permitted';
      if (Platform.isAndroid && notPermitted) {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          ts,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      } else {
        rethrow;
      }
    }
  }

  Future<void> scheduleSameDayTwoHoursBefore({
    required String appointmentId,
    required DateTime appointmentDateTime,
    required String title,
    required String body,
  }) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    if (appointmentDateTime.isBefore(start) ||
        !appointmentDateTime.isBefore(end)) {
      return;
    }
    final trigger = appointmentDateTime.subtract(const Duration(hours: 2));
    final id = stableId('appt-$appointmentId-2h');
    await scheduleAt(
      id: id,
      title: title,
      body: body,
      whenLocal: trigger,
      payload: 'appt:$appointmentId',
    );
  }

  Future<bool> areEnabled() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  Future<void> cancelForAppointment(String appointmentId) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final r in pending) {
      if ((r.payload ?? '') == 'appt:$appointmentId') {
        await _plugin.cancel(r.id);
      }
    }
    await _plugin.cancel(stableId('appt-$appointmentId-2h'));
  }

  Future<void> showNow({
    int id = 9999,
    String title = 'Test',
    String body = 'It works!',
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> scheduleInSeconds(int seconds) async {
    final when = DateTime.now().add(Duration(seconds: seconds));
    await scheduleAt(
      id: stableId('debug-$seconds'),
      title: 'Scheduled',
      body: '+$seconds sec',
      whenLocal: when,
    );
  }

  Future<List<PendingNotificationRequest>> pendingNotificationRequests() {
    return _plugin.pendingNotificationRequests();
  }
}
