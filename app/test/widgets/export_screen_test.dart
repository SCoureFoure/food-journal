import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/screens/export/export_screen.dart';

/// export_import_size AC2 — the Export screen defaults to a data-only export:
/// the "Photos" switch is off, so a default export embeds no image bytes.
/// (The payload-exclusion behaviour itself is proven by the includeImages:false
/// unit tests in export_import_test.dart.)
void main() {
  group('[BVA] ExportScreen photo toggle default', () {
    SwitchListTile tileWithTitle(WidgetTester tester, String title) {
      return tester.widget<SwitchListTile>(
        find.ancestor(
          of: find.text(title),
          matching: find.byType(SwitchListTile),
        ),
      );
    }

    testWidgets('Photos switch defaults off', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ExportScreen()));
      await tester.pump();

      expect(tileWithTitle(tester, 'Photos').value, isFalse);
    });

    testWidgets('Meals switch defaults on (control)', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ExportScreen()));
      await tester.pump();

      expect(tileWithTitle(tester, 'Meals').value, isTrue);
    });
  });
}
