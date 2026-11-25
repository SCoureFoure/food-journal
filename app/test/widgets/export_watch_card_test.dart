import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/screens/export/export_screen.dart';
import 'package:food_journal/services/settings_service.dart';
import 'package:food_journal/services/watch_folder.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAccess implements WatchFolderAccess {
  @override
  Future<WatchFolderLink?> pickFolder() async => null;
  @override
  Future<WatchFileStat?> stat(String uri, String name) async => null;
  @override
  Future<String?> copy(String uri, String name) async => null;
}

Finder _anchor(String id) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == id,
    );

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    home: ExportScreen(watchAccess: _FakeAccess(), settings: SettingsService()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('[MFT] watch card (AC13)', () {
    // testTheory: MFT
    // contract: a linked folder shows its label and all three buttons with Import now enabled; no folder reads Not set and disables Import now.
    // implication: AC13 — if this fails, the user cannot tell whether auto import is configured or trigger it.
    testWidgets('linked: label shown, three buttons, Import now enabled', (tester) async {
      SharedPreferences.setMockInitialValues({
        'watch_folder_uri': 'content://x',
        'watch_folder_label': 'Internal storage/Documents/Gadgetbridge',
      });
      await _pump(tester);

      expect(find.descendant(
          of: _anchor('watch-folder-path'),
          matching: find.text('Internal storage/Documents/Gadgetbridge')), findsOneWidget);
      expect(_anchor('btn-watch-set-folder'), findsOneWidget);
      expect(_anchor('btn-watch-import-now'), findsOneWidget);
      expect(_anchor('btn-import-watch'), findsOneWidget);
      final now = tester.widget<ButtonStyleButton>(find.descendant(
          of: _anchor('btn-watch-import-now'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));
      expect(now.onPressed, isNotNull);
    });

    testWidgets('unlinked: Not set, Import now disabled', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pump(tester);

      expect(find.descendant(
          of: _anchor('watch-folder-path'), matching: find.text('Not set')), findsOneWidget);
      final now = tester.widget<ButtonStyleButton>(find.descendant(
          of: _anchor('btn-watch-import-now'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));
      expect(now.onPressed, isNull);
    });
  });
}
