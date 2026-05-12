import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static const _channelId = 'meal_checkin';
  static const _channelName = 'Meal Check-ins';

  final _plugin = FlutterLocalNotificationsPlugin();

  int get _delayMinutes {
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
    int mealId,
    String mealLabel,
    DateTime mealTime,
  ) async {
    final scheduledTime = tz.TZDateTime.from(
      mealTime.add(Duration(minutes: _delayMinutes)),
      tz.local,
    );

    await _plugin.zonedSchedule(
      mealId,
      'How did you feel after $mealLabel?',
      'Tap to log any reactions.',
      scheduledTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'checkin:$mealId',
    );
  }

  Future<void> cancelCheckin(int mealId) async {
    await _plugin.cancel(mealId);
  }
}
