import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/services/notification_service.dart';

void main() {
  group('[EQUIV] routeForPayload — Fix B', () {
    test('a check-in payload opens that entry', () {
      // testTheory: equivalence — 'checkin:<id>' maps to the check-in route with the id.
      // contract: 'checkin:42' → NotificationRoute(checkin, entryId 42).
      // implication: AC9 — tapping a reaction reminder opens that entry's check-in.
      expect(
        routeForPayload('checkin:42'),
        const NotificationRoute(NotificationRouteKind.checkin, entryId: 42),
      );
    });

    test('the hungry nudge opens Log Meal', () {
      // testTheory: equivalence — 'nudge:meal' maps to the log-meal route.
      // contract: 'nudge:meal' → NotificationRoute(logMeal).
      // implication: AC9 — tapping the hungry nudge starts a meal log.
      expect(
        routeForPayload('nudge:meal'),
        const NotificationRoute(NotificationRouteKind.logMeal),
      );
    });

    test('the thirsty nudge opens water logging', () {
      // testTheory: equivalence — 'nudge:water' maps to the log-water route.
      // contract: 'nudge:water' → NotificationRoute(logWater).
      // implication: AC9 — tapping the thirsty nudge leads to logging water.
      expect(
        routeForPayload('nudge:water'),
        const NotificationRoute(NotificationRouteKind.logWater),
      );
    });

    test('null and malformed payloads route nowhere', () {
      // testTheory: boundary value — unknown or broken payloads are ignored.
      // contract: null, a non-numeric id, and an unknown string all → null.
      // implication: AC9 — only known payloads navigate; nothing else does.
      expect(routeForPayload(null), isNull);
      expect(routeForPayload('checkin:abc'), isNull);
      expect(routeForPayload('whatever'), isNull);
      expect(routeForPayload('nudge:steps'), isNull);
    });
  });
}
