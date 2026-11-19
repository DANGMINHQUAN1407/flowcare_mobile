import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/appointment_model.dart';
import '../models/follow_up_order_model.dart';

class ScheduledReminderItem {
  final int id;
  final String title;
  final String body;
  final DateTime scheduledTime;
  final String type; // 'follow_up' or 'appointment'
  final String referenceId;

  const ScheduledReminderItem({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledTime,
    required this.type,
    required this.referenceId,
  });
}

class LocalReminderService {
  static final LocalReminderService _instance = LocalReminderService._internal();
  factory LocalReminderService() => _instance;
  LocalReminderService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  final Set<int> _activeScheduledIds = {};

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Local notification clicked: ${response.payload}');
        },
      );

      _initialized = true;
    } catch (e) {
      debugPrint('LocalReminderService initialization error: $e');
    }
  }

  Future<bool> requestPermissions() async {
    if (!_initialized) await initialize();
    try {
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final granted = await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }
      final iosImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (iosImplementation != null) {
        final granted = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
    return true;
  }

  /// Unique hash code helper for generating integer notification IDs from string IDs.
  int _generateId(String key, String suffix) {
    return (key + suffix).hashCode & 0x7FFFFFFF;
  }

  /// Schedule local notification reminders for a follow-up order (FollowUpOrderModel).
  /// Schedules 2 reminders:
  /// 1. Day before the scheduled follow-up date (at 09:00 AM)
  /// 2. On the exact target date/time (or 2 hours before targetTime)
  Future<List<int>> scheduleFollowUpReminders(FollowUpOrderModel order) async {
    if (!_initialized) await initialize();
    final scheduledIds = <int>[];

    final targetAt = order.targetAt;
    final targetDate = order.targetDate;
    final timeStr = order.targetTime ?? '08:30';
    final timeParts = timeStr.split(':');
    final hour = timeParts.length >= 2 ? (int.tryParse(timeParts[0]) ?? 8) : 8;
    final minute = timeParts.length >= 2 ? (int.tryParse(timeParts[1]) ?? 30) : 30;

    final actualDateTime = targetAt ??
        DateTime(targetDate.year, targetDate.month, targetDate.day, hour, minute);

    final now = DateTime.now();

    // 1. Reminder 1 day prior at 09:00 AM
    final dayBefore = DateTime(
      actualDateTime.year,
      actualDateTime.month,
      actualDateTime.day,
      9,
      0,
    ).subtract(const Duration(days: 1));

    if (dayBefore.isAfter(now)) {
      final id1 = _generateId(order.id, '_day_before');
      final title = 'Nhắc lịch tái khám ngày mai';
      final body =
          'Bạn có lịch tái khám (${order.departmentName}) vào ${order.targetTime ?? "ngày mai"}. Bác sĩ: ${order.originalDoctorName}.';
      final scheduled = await _scheduleSingleNotification(
        id: id1,
        title: title,
        body: body,
        scheduledDateTime: dayBefore,
        payload: 'follow_up:${order.id}',
      );
      if (scheduled) scheduledIds.add(id1);
    }

    // 2. Reminder 2 hours before actual scheduled time (or exact time)
    final sameDayReminder = actualDateTime.subtract(const Duration(hours: 2));
    if (sameDayReminder.isAfter(now)) {
      final id2 = _generateId(order.id, '_same_day');
      final title = 'Lịch tái khám hôm nay';
      final body =
          'Sắp tới giờ tái khám lúc ${order.targetTime ?? "hôm nay"}. Vui lòng kiểm tra và đến đúng hẹn tại ${order.departmentName}.';
      final scheduled = await _scheduleSingleNotification(
        id: id2,
        title: title,
        body: body,
        scheduledDateTime: sameDayReminder,
        payload: 'follow_up:${order.id}',
      );
      if (scheduled) scheduledIds.add(id2);
    }

    return scheduledIds;
  }

  /// Schedule local notification reminders for an upcoming appointment (AppointmentModel).
  Future<List<int>> scheduleAppointmentReminders(AppointmentModel appointment) async {
    if (!_initialized) await initialize();
    final scheduledIds = <int>[];
    final now = DateTime.now();
    final scheduledTime = appointment.scheduledTime;

    // 1. Reminder 1 day prior at 08:30 AM
    final dayBefore = DateTime(
      scheduledTime.year,
      scheduledTime.month,
      scheduledTime.day,
      8,
      30,
    ).subtract(const Duration(days: 1));

    if (dayBefore.isAfter(now)) {
      final id1 = _generateId(appointment.id, '_app_day_before');
      final title = 'Nhắc lịch hẹn khám ngày mai';
      final body =
          'Bạn có lịch hẹn khám ${appointment.serviceTypeName} vào ngày mai lúc ${_formatTime(scheduledTime)}.';
      final scheduled = await _scheduleSingleNotification(
        id: id1,
        title: title,
        body: body,
        scheduledDateTime: dayBefore,
        payload: 'appointment:${appointment.id}',
      );
      if (scheduled) scheduledIds.add(id1);
    }

    // 2. Reminder 2 hours prior
    final exactReminder = scheduledTime.subtract(const Duration(hours: 2));
    if (exactReminder.isAfter(now)) {
      final id2 = _generateId(appointment.id, '_app_2h_before');
      final title = 'Sắp tới giờ hẹn khám';
      final body =
          'Lịch hẹn ${appointment.serviceTypeName} sẽ diễn ra lúc ${_formatTime(scheduledTime)}. Vui lòng chuẩn bị và check-in tại bệnh viện.';
      final scheduled = await _scheduleSingleNotification(
        id: id2,
        title: title,
        body: body,
        scheduledDateTime: exactReminder,
        payload: 'appointment:${appointment.id}',
      );
      if (scheduled) scheduledIds.add(id2);
    }

    return scheduledIds;
  }

  Future<bool> _scheduleSingleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    required String payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'flowcare_followup_reminders',
        'Nhắc Nhở Lịch Khám & Tái Khám',
        channelDescription:
            'Thông báo nhắc nhở tự động về lịch hẹn khám và phiếu tái khám cho bệnh nhân',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final tzScheduled = tz.TZDateTime.from(scheduledDateTime, tz.local);

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduled,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

      _activeScheduledIds.add(id);
      return true;
    } catch (e) {
      debugPrint('Failed to schedule local notification (ID: $id): $e');
      return false;
    }
  }

  Future<void> cancelReminder(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
      _activeScheduledIds.remove(id);
    } catch (e) {
      debugPrint('Failed to cancel reminder $id: $e');
    }
  }

  Future<void> cancelAllReminders() async {
    try {
      await _notificationsPlugin.cancelAll();
      _activeScheduledIds.clear();
    } catch (e) {
      debugPrint('Failed to cancel all reminders: $e');
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
