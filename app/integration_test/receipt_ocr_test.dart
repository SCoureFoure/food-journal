import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/receipt_parser.dart';
import 'package:food_journal/services/receipt_ocr_service.dart';
import 'package:integration_test/integration_test.dart';

// On-device OCR check (AC9). Inputs are served from the host, because installing
// the app wipes anything pushed into its storage and the emulator cannot fit a
// debug build (run-as). From the repo root:
//
//   python -m http.server 8765 --bind 127.0.0.1 --directory <dir with inputs>
//   adb reverse tcp:8765 tcp:8765
//   cd app && flutter drive --profile -d <device> //     --driver=test_driver/integration_test.dart //     --target=integration_test/receipt_ocr_test.dart //     --dart-define=RECEIPT_OCR_BASE_URL=http://127.0.0.1:8765
//
// Inputs: synthetic.png (copy of test/fixtures/receipt_ocr/synthetic.png), and
// optionally private.jpg + private.expected.txt (one expected item `raw` per line;
// never committed — real receipts carry card digits). Each test skips when its
// input is unavailable.

const _baseUrl = String.fromEnvironment('RECEIPT_OCR_BASE_URL');

Future<Uint8List?> _input(String name) async {
  if (_baseUrl.isEmpty) return null;
  final client = HttpClient();
  try {
    final res = await (await client.getUrl(Uri.parse('$_baseUrl/$name'))).close();
    if (res.statusCode != 200) return null;
    final builder = BytesBuilder(copy: false);
    await res.forEach(builder.add);
    return builder.takeBytes();
  } on IOException {
    return null;
  } finally {
    client.close();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final reader = OnnxReceiptReader();

  testWidgets('synthetic receipt reads exactly like the Python reference', (tester) async {
    // testTheory: equivalence — same models, same pre/post-processing, same text.
    // contract: OnnxReceiptReader.readLines on the fixture image returns the
    //   reference's five lines.
    // implication: AC9 — the native runtime and asset loading work on Android.
    final png = await tester.runAsync(() => _input('synthetic.png'));
    if (png == null) {
      markTestSkipped('synthetic.png not served');
      return;
    }
    final lines = await tester.runAsync(() => reader.readLines(png));
    expect(lines, [
      'GROCERY',
      'LIMES 0.59',
      'HRD STM IB WGB EX FN W',
      '2 @ 1.39 2.78',
      'BALANCE DUE 3.37',
    ]);
  });

  testWidgets('private receipt: parser finds at least 90% of expected items', (tester) async {
    // testTheory: minimum functionality on a real photo.
    // contract: >= 90% of expected raws have a parsed item with
    //   sequenceRatio >= 0.80.
    // implication: AC9 — end-to-end accuracy on the phone matches the bake-off.
    final jpg = await tester.runAsync(() => _input('private.jpg'));
    final expectedBytes = await tester.runAsync(() => _input('private.expected.txt'));
    if (jpg == null || expectedBytes == null) {
      markTestSkipped('no private receipt served');
      return;
    }
    final sw = Stopwatch()..start();
    final lines = await tester.runAsync(() => reader.readLines(jpg));
    final items = parseReceiptText(lines!.join('\n'));
    final expected = const LineSplitter().convert(utf8.decode(expectedBytes)).where((l) => l.trim().isNotEmpty).toList();
    final found = expected.where((raw) {
      final want = normalizeReceiptLine(raw);
      return items.any((i) => sequenceRatio(want, i.raw) >= 0.80);
    }).length;
    // ignore: avoid_print
    print('RECEIPT_OCR found $found/${expected.length} items in ${sw.elapsedMilliseconds} ms');
    expect(found / expected.length, greaterThanOrEqualTo(0.90));
  });
}
