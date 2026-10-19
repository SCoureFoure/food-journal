import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/receipt_ocr/ocr_ops.dart';
import 'package:food_journal/models/receipt_ocr/ocr_pipeline.dart';
import 'package:food_journal/services/receipt_ocr_service.dart';
import 'package:integration_test/integration_test.dart';

// Stage timing for the receipt OCR pipeline. Run like receipt_ocr_test.dart
// (see that file's header); needs private.jpg served.

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

/// Wraps a runner and accumulates time spent in each model call.
class _TimingRunner implements OcrModelRunner {
  final OcrModelRunner inner;
  int detMs = 0;
  int recMs = 0;
  int recCalls = 0;
  int recOutValues = 0;

  _TimingRunner(this.inner);

  @override
  Future<Float32List> detect(Float32List input, int h, int w) async {
    final sw = Stopwatch()..start();
    final result = await inner.detect(input, h, w);
    detMs += sw.elapsedMilliseconds;
    return result;
  }

  @override
  Future<RecBatchOutput> recognizeBatch(Float32List input, int n, int w) async {
    final sw = Stopwatch()..start();
    final out = await inner.recognizeBatch(input, n, w);
    recMs += sw.elapsedMilliseconds;
    recCalls++;
    recOutValues += out.idx.length + out.maxp.length;
    return out;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile: stage timing on private receipt', (tester) async {
    // testTheory: measurement (groundwork, not a contract).
    // contract: prints per-stage timings; passes when any text is read.
    // implication: phase 1 speed fix — baseline and after numbers.
    final jpg = await tester.runAsync(() => _input('private.jpg'));
    if (jpg == null) {
      markTestSkipped('no private receipt served');
      return;
    }
    await tester.runAsync(() async {
      final reader = OnnxReceiptReader();

      final coldSw = Stopwatch()..start();
      await reader.readLines(jpg);
      final coldMs = coldSw.elapsedMilliseconds;

      final ocrChars = (await rootBundle.loadString(OnnxReceiptReader.dictAsset)).split('\n');
      if (ocrChars.isNotEmpty && ocrChars.last.isEmpty) ocrChars.removeLast();

      final decodeSw = Stopwatch()..start();
      final image = decodeRgbImage(jpg);
      final decodeMs = decodeSw.elapsedMilliseconds;

      final t = _TimingRunner(reader);
      final warmSw = Stopwatch()..start();
      final lines = await readReceiptLines(image!, t, ocrChars);
      final totalMs = warmSw.elapsedMilliseconds;

      // ignore: avoid_print
      print('PROFILE cold_ms=$coldMs decode_ms=$decodeMs warm_total_ms=$totalMs det_ms=${t.detMs} rec_ms=${t.recMs} rec_calls=${t.recCalls} rec_out_mb=${(t.recOutValues * 4 / 1e6).toStringAsFixed(1)} dart_ms=${totalMs - t.detMs - t.recMs} lines=${lines.length}');
      expect(lines, isNotEmpty);
    });
  });
}
