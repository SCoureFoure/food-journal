import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static const _channelId = 'meal_checkin';
  static const _channelName = 'Check-ins';

  final _plugin = FlutterLocalNotificationsPlugin();

  int get _defaultDelayMinutes {
    final val = int.tryParse(dotenv.env['CHECKIN_DELAY_MINUTES'] ?? '');
    return val ?? 90;
  }

  Future<void> initialize() async {
    tz.initializeTimeZones();
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleCheckin(
    int entryId,
    String label,
    DateTime entryTime, {
    int? delayMinutes,
  }) async {
    final delay = delayMinutes ?? _defaultDelayMinutes;
    final scheduledTime = tz.TZDateTime.from(
      entryTime.add(Duration(minutes: delay)),
      tz.local,
    );

    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      entryId,
      'How did you feel after $label?',
      'Tap to log any reactions.',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'checkin:$entryId',
    );
  }

  Future<void> cancelCheckin(int entryId) async {
    await _plugin.cancel(entryId);
  }
}
