import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/pet_nudge.dart';

/// Where a tapped notification should take the user. Pure, so it is unit-tested
/// without any navigation (see specs/pet_nudges.spec.md AC9).
enum NotificationRouteKind { checkin, logMeal, logWater }

class NotificationRoute {
  final NotificationRouteKind kind;
  final int? entryId;
  const NotificationRoute(this.kind, {this.entryId});

  @override
  bool operator ==(Object other) =>
      other is NotificationRoute &&
      other.kind == kind &&
      other.entryId == entryId;

  @override
  int get hashCode => Object.hash(kind, entryId);

  @override
  String toString() => 'NotificationRoute($kind, entryId: $entryId)';
}

/// Maps a notification payload to a destination. Returns null for anything
/// unknown or malformed.
NotificationRoute? routeForPayload(String? payload) {
  if (payload == null) return null;
  if (payload.startsWith('checkin:')) {
    final id = int.tryParse(payload.substring('checkin:'.length));
    if (id == null) return null;
    return NotificationRoute(NotificationRouteKind.checkin, entryId: id);
  }
  if (payload == 'nudge:meal') {
    return const NotificationRoute(NotificationRouteKind.logMeal);
  }
  if (payload == 'nudge:water') {
    return const NotificationRoute(NotificationRouteKind.logWater);
  }
  return null;
}

class NotificationService {
  static const _channelId = 'meal_checkin';
  static const _channelName = 'Check-ins';
  static const _nudgeChannelId = 'pet_nudge';
  static const _nudgeChannelName = 'Pet reminders';

  /// Set by the app to route a tapped notification. Kept static so the plugin
  /// callback can reach it.
  static void Function(NotificationRoute route)? onRoute;

  final _plugin = FlutterLocalNotificationsPlugin();

  int get _defaultDelayMinutes {
    final val = int.tryParse(dotenv.env['CHECKIN_DELAY_MINUTES'] ?? '');
    return val ?? 90;
  }

  // Fix A: meals keep their entry id; medications are offset so the two never
  // overwrite each other's notification.
  int _checkinId(int entryId, bool isMedication) =>
      isMedication ? entryId + medCheckinIdOffset : entryId;

  int _nudgeId(PetNudgeKind kind) =>
      switch (kind) { PetNudgeKind.hungry => nudgeHungryId, PetNudgeKind.thirsty => nudgeThirstyId };

  String _nudgePayload(PetNudgeKind kind) =>
      switch (kind) { PetNudgeKind.hungry => 'nudge:meal', PetNudgeKind.thirsty => 'nudge:water' };

  Future<void> initialize() async {
    tz.initializeTimeZones();
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _handleResponse,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // Fix B: route a tap by its payload. Static so it can be used as the plugin
  // callback.
  static void _handleResponse(NotificationResponse response) {
    final route = routeForPayload(response.payload);
    if (route != null) onRoute?.call(route);
  }

  Future<void> scheduleCheckin(
    int entryId,
    String label,
    DateTime entryTime, {
    int? delayMinutes,
    bool isMedication = false,
  }) async {
    final delay = delayMinutes ?? _defaultDelayMinutes;
    final scheduledTime = tz.TZDateTime.from(
      entryTime.add(Duration(minutes: delay)),
      tz.local,
    );

    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      _checkinId(entryId, isMedication),
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

  Future<void> cancelCheckin(int entryId, {bool isMedication = false}) async {
    await _plugin.cancel(_checkinId(entryId, isMedication));
  }

  /// Schedule a gentle pet reminder at [when]. Caller decides when via
  /// [dueNudges]; this just places it.
  Future<void> schedulePetNudge(PetNudgeKind kind, DateTime when) async {
    final scheduledTime = tz.TZDateTime.from(when, tz.local);
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) return;
    final copy = petNudgeCopy[kind]!;
    await _plugin.zonedSchedule(
      _nudgeId(kind),
      copy.title,
      copy.body,
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _nudgeChannelId,
          _nudgeChannelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: _nudgePayload(kind),
    );
  }

  Future<void> cancelPetNudge(PetNudgeKind kind) async {
    await _plugin.cancel(_nudgeId(kind));
  }
}
