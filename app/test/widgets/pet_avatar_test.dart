import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/pet_feed.dart';
import 'package:food_journal/widgets/pet/pet_avatar.dart';

double _dy(WidgetTester t) => t
    .widget<Transform>(find.byKey(const ValueKey('pet-avatar-bounce')))
    .transform
    .getTranslation()
    .y;

Future<void> _pump(
  WidgetTester tester,
  ValueNotifier<PetFeed?> notifier, {
  VoidCallback? onTap,
  bool reducedMotion = false,
}) async {
  Widget body = Center(
    child: PetAvatar(feed: notifier, onTap: onTap ?? () {}),
  );
  if (reducedMotion) {
    body = MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: body,
    );
  }
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: body)));
}

ValueNotifier<PetFeed?> _notifier() => ValueNotifier<PetFeed?>(
    const PetFeed(mealsToday: 2, waterMl: 946, waterGoalMl: 1893));

void main() {
  group('[DIR] PetAvatar bounces when fed', () {
    testWidgets('more meals bounces then settles', (tester) async {
      // testTheory: DIR
      // contract: meals going up makes the avatar rise, then return to rest
      // implication: AC8 - feeding the pet gives visible feedback
      final notifier = _notifier();
      await _pump(tester, notifier);
      notifier.value =
          const PetFeed(mealsToday: 3, waterMl: 946, waterGoalMl: 1893);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_dy(tester), lessThan(0));
      await tester.pumpAndSettle();
      expect(_dy(tester), 0);
    });

    testWidgets('more water bounces', (tester) async {
      // testTheory: DIR
      // contract: water going up makes the avatar rise
      // implication: AC8 - water logging also feeds the pet
      final notifier = _notifier();
      await _pump(tester, notifier);
      notifier.value =
          const PetFeed(mealsToday: 2, waterMl: 1196, waterGoalMl: 1893);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_dy(tester), lessThan(0));
      await tester.pumpAndSettle();
    });
  });

  group('[INV] PetAvatar does not bounce without feeding', () {
    testWidgets('fewer meals does not bounce', (tester) async {
      // testTheory: INV
      // contract: a decrease in meals never triggers the bounce
      // implication: AC8 - deleting an entry is not feeding
      final notifier = _notifier();
      await _pump(tester, notifier);
      notifier.value =
          const PetFeed(mealsToday: 1, waterMl: 946, waterGoalMl: 1893);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_dy(tester), 0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('goal-only change does not bounce', (tester) async {
      // testTheory: INV
      // contract: changing only the water goal never triggers the bounce
      // implication: AC8 - editing goals is not feeding
      final notifier = _notifier();
      await _pump(tester, notifier);
      notifier.value =
          const PetFeed(mealsToday: 2, waterMl: 946, waterGoalMl: 2366);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_dy(tester), 0);
    });

    testWidgets('first build does not bounce', (tester) async {
      // testTheory: INV
      // contract: an initial value never bounces
      // implication: AC8 - opening the app is not feeding
      final notifier = _notifier();
      await _pump(tester, notifier);
      await tester.pump(const Duration(milliseconds: 200));
      expect(_dy(tester), 0);
    });

    testWidgets('null to value does not bounce', (tester) async {
      // testTheory: INV
      // contract: first load (null -> value) never bounces
      // implication: AC8 - initial data load is not feeding
      final notifier = ValueNotifier<PetFeed?>(null);
      await _pump(tester, notifier);
      notifier.value =
          const PetFeed(mealsToday: 2, waterMl: 946, waterGoalMl: 1893);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_dy(tester), 0);
    });

    testWidgets('reduced motion suppresses bounce', (tester) async {
      // testTheory: INV
      // contract: with disableAnimations, feeding never moves the avatar
      // implication: AC8 - respects the reduced-motion setting
      final notifier = _notifier();
      await _pump(tester, notifier, reducedMotion: true);
      notifier.value =
          const PetFeed(mealsToday: 3, waterMl: 946, waterGoalMl: 1893);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_dy(tester), 0);
    });
  });

  group('[MFT] PetAvatar tap and anchor', () {
    testWidgets('tap calls onTap once; anchor exists', (tester) async {
      // testTheory: MFT
      // contract: tapping fires onTap once; pet-avatar anchor is declared once
      // implication: AC8 - the avatar is reachable and opens the pet
      var taps = 0;
      await _pump(tester, _notifier(), onTap: () => taps++);
      await tester.tap(find.byType(PetAvatar));
      expect(taps, 1);
      expect(
        find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.identifier == 'pet-avatar'),
        findsOneWidget,
      );
    });
  });
}
