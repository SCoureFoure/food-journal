import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/receipt_ocr/ocr_ops.dart';
import 'package:food_journal/models/receipt_ocr/ocr_pipeline.dart';

void _pointsClose(List<(double, double)> actual, List<(double, double)> expected, {double tol = 1e-6}) {
  expect(actual.length, expected.length);
  for (var i = 0; i < expected.length; i++) {
    expect(actual[i].$1, closeTo(expected[i].$1, tol), reason: 'x of point $i');
    expect(actual[i].$2, closeTo(expected[i].$2, tol), reason: 'y of point $i');
  }
}

/// Fake runner fed from the reference fixture: returns the reference detector map
/// and rebuilds each recogniser output from its argmax / max-probability rows.
class _FixtureRunner implements OcrModelRunner {
  _FixtureRunner(this.fixture, this.prob);
  final Map<String, dynamic> fixture;
  final Float32List prob;
  final detCalls = <(int, int, double)>[];
  final recCalls = <(int, int, double)>[];
  final _consumed = <int>{};

  @override
  Future<Float32List> detect(Float32List input, int h, int w) async {
    detCalls.add((h, w, input.fold<double>(0, (a, b) => a + b)));
    return prob;
  }

  @override
  Future<RecBatchOutput> recognizeBatch(Float32List input, int n, int w) async {
    final boxes = (fixture['boxes'] as List).cast<Map<String, dynamic>>();
    final rowIdx = <List<int>>[];
    final rowProb = <List<double>>[];
    for (var r = 0; r < n; r++) {
      final row = input.sublist(r * 3 * 48 * w, (r + 1) * 3 * 48 * w);
      final rowSum = row.fold<double>(0, (a, b) => a + b);
      int? best;
      var bestDiff = double.infinity;
      for (var i = 0; i < boxes.length; i++) {
        if (_consumed.contains(i) || (boxes[i]['rec_w'] as int) > w) continue;
        final diff = ((boxes[i]['rec_input_sum'] as num).toDouble() - rowSum).abs();
        if (diff < bestDiff) {
          bestDiff = diff;
          best = i;
        }
      }
      final i = best!;
      _consumed.add(i);
      recCalls.add((i, w, rowSum));
      rowIdx.add((boxes[i]['argmax'] as List).cast<int>());
      rowProb.add((boxes[i]['maxprob'] as List).map((e) => (e as num).toDouble()).toList());
    }
    final steps = rowIdx.fold<int>(0, (a, b) => a > b.length ? a : b.length);
    final idx = <int>[];
    final maxp = <double>[];
    for (var r = 0; r < n; r++) {
      idx.addAll(rowIdx[r]);
      maxp.addAll(rowProb[r]);
      for (var t = rowIdx[r].length; t < steps; t++) {
        idx.add(0);
        maxp.add(0.0);
      }
    }
    return RecBatchOutput(idx, maxp, steps);
  }
}

void main() {
  group('[MFT] OCR primitives match the Python reference', () {
    // testTheory: minimum functionality — each primitive returns the reference's
    //   values on the reference's own unit cases (bakeoff/test_ref_ocr.py).
    // contract: half-pixel bilinear, (x/255-0.5)/0.5, 2x2 dilation toward
    //   down-right, 8-connected components in row-major order, monotone-chain
    //   hull, rotating-calipers rectangle ordered TL,TR,BR,BL, unclip by
    //   area*ratio/perimeter, rotated crop, 48-px recogniser input padded to 320,
    //   CTC greedy decode.
    // implication: AC7 — a drifting primitive silently lowers OCR accuracy;
    //   the bake-off numbers only hold while the port matches the reference.

    test('detResizeShape clamps, upscales and rounds to 32', () {
      expect(detResizeShape(4000, 3000), (2016, 1504));
      expect(detResizeShape(500, 300), (1216, 736));
      expect(detResizeShape(10, 10), (736, 736));
    });

    test('normalizeChw maps 0..255 to -1..1 in CHW order', () {
      final out = normalizeChw(Float32List.fromList([0, 255, 51]), 1, 1);
      expect(out.length, 3);
      expect(out[0], closeTo(-1.0, 1e-6));
      expect(out[1], closeTo(1.0, 1e-6));
      expect(out[2], closeTo(-0.6, 1e-6));
    });

    test('resizeBilinear uses half-pixel centres', () {
      final out = resizeBilinear(Float32List.fromList([0, 100, 100, 200]), 2, 2, 1, 4, 4);
      const expected = [0, 25, 75, 100, 25, 50, 100, 125, 75, 100, 150, 175, 100, 125, 175, 200];
      for (var i = 0; i < 16; i++) {
        expect(out[i], closeTo(expected[i], 1e-4), reason: 'pixel $i');
      }
      expect(resizeBilinear(Float32List(2 * 2 * 3), 2, 2, 3, 5, 7).length, 5 * 7 * 3);
    });

    test('dilate2x2 grows down and right', () {
      final b = Uint8List(9)..[4] = 1;
      final out = dilate2x2(b, 3, 3);
      expect([for (var i = 0; i < 9; i++) if (out[i] != 0) i], [4, 5, 7, 8]);
    });

    test('components joins diagonals and orders by first pixel', () {
      final chain = Uint8List.fromList([0, 0, 0, 1, 1, 0, 1, 0, 0, 1, 0, 0]);
      final one = components(chain, 3, 4);
      expect(one.length, 1);
      expect([...one[0]]..sort(), [3, 4, 6, 9]);

      final two = components(Uint8List.fromList([0, 0, 1, 0, 0, 0, 1, 0, 0]), 3, 3);
      expect(two.map((c) => [...c]..sort()).toList(), [[2], [6]]);
    });

    test('convexHull drops interior and collinear points', () {
      final hull = convexHull(const [(0, 0), (2, 0), (2, 2), (0, 2), (1, 1), (1, 0)]);
      final sorted = [...hull]..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
      expect(sorted, const [(0.0, 0.0), (0.0, 2.0), (2.0, 0.0), (2.0, 2.0)]);
    });

    test('minAreaRect on an axis-aligned pixel block', () {
      final pts = [for (var x = 2; x < 10; x++) for (var y = 3; y < 6; y++) (x.toDouble(), y.toDouble())];
      final r = minAreaRect(pts);
      _pointsClose(r.corners, const [(2, 3), (9, 3), (9, 5), (2, 5)]);
      expect([r.w, r.h].reduce((a, b) => a > b ? a : b), closeTo(7, 1e-9));
      expect([r.w, r.h].reduce((a, b) => a < b ? a : b), closeTo(2, 1e-9));
    });

    test('minAreaRect finds the rotated rectangle', () {
      final r = minAreaRect(const [(0, 0), (4, 2), (3, 4), (-1, 2)]);
      _pointsClose(r.corners, const [(0, 0), (4, 2), (3, 4), (-1, 2)]);
      expect(r.w * r.h, closeTo(10, 1e-6));
    });

    test('unclipRect expands every side by area*ratio/perimeter', () {
      final r = unclipRect(const [(0, 0), (10, 0), (10, 2), (0, 2)], ratio: 1.6);
      const d = 20 * 1.6 / 24;
      _pointsClose(r.corners, const [(-d, -d), (10 + d, -d), (10 + d, 2 + d), (-d, 2 + d)]);
      expect(r.w, closeTo(10 + 2 * d, 1e-9));
      expect(r.h, closeTo(2 + 2 * d, 1e-9));
    });

    RgbImage gradient() {
      final data = Uint8List(10 * 10 * 3);
      for (var y = 0; y < 10; y++) {
        for (var x = 0; x < 10; x++) {
          for (var c = 0; c < 3; c++) {
            data[(y * 10 + x) * 3 + c] = x + 10 * y;
          }
        }
      }
      return RgbImage(10, 10, data);
    }

    test('cropRotated on an axis-aligned box equals a slice', () {
      final img = gradient();
      final out = cropRotated(img, const [(2, 1), (6, 1), (6, 4), (2, 4)]);
      expect((out.width, out.height), (4, 3));
      for (var v = 0; v < 3; v++) {
        for (var u = 0; u < 4; u++) {
          expect(out.data[(v * 4 + u) * 3], (2 + u) + 10 * (1 + v));
        }
      }
    });

    test('cropRotated turns a tall crop on its side', () {
      final out = cropRotated(gradient(), const [(2, 1), (4, 1), (4, 7), (2, 7)]);
      expect((out.width, out.height), (6, 2));
    });

    test('recInput resizes to 48 high and pads to 320 with zero', () {
      final white = RgbImage(48, 24, Uint8List(48 * 24 * 3)..fillRange(0, 48 * 24 * 3, 255));
      final r = recInput(white);
      expect(r.width, 320);
      expect(r.data.length, 3 * 48 * 320);
      expect(r.data[10 * 320 + 50], closeTo(1.0, 1e-5));
      expect(r.data[10 * 320 + 200], 0.0);

      final wide = recInput(RgbImage(100, 10, Uint8List(100 * 10 * 3)));
      expect(wide.width, 480);
    });

    test('ctcDecode collapses repeats and drops blanks', () {
      const idx = [1, 1, 0, 1, 2, 3, 3];
      const top = [0.9, 0.8, 0.99, 0.7, 0.6, 0.5, 0.4];
      final probs = Float32List(7 * 4);
      for (var t = 0; t < 7; t++) {
        for (var c = 0; c < 4; c++) {
          probs[t * 4 + c] = (1 - top[t]) / 3;
        }
        probs[t * 4 + idx[t]] = top[t];
      }
      final r = ctcDecode(probs, 7, 4, const ['a', 'b']);
      expect(r.$1, 'aab ');
      expect(r.$2, closeTo((0.9 + 0.7 + 0.6 + 0.5) / 4, 1e-5));

      final blank = Float32List(3 * 4)..[0] = 1..[4] = 1..[8] = 1;
      expect(ctcDecode(blank, 3, 4, const ['a', 'b']), ('', 0.0));
    });

    test('groupRows joins boxes on one row left to right', () {
      final text = groupRows(const [
        [(50, 10), (90, 10), (90, 20), (50, 20)],
        [(0, 12), (40, 12), (40, 22), (0, 22)],
        [(0, 40), (40, 40), (40, 50), (0, 50)],
      ], const ['0.59', 'LIMES', 'TOTAL']);
      expect(text, 'LIMES 0.59\nTOTAL');
    });
  });

  group('[EQUIV] OCR pipeline matches the reference on a synthetic receipt', () {
    // testTheory: equivalence — same detector map and recogniser outputs in,
    //   same boxes, crops and text out, as the Python reference.
    // contract: readReceiptLines drives the runner exactly as ref_ocr.ocr_image
    //   does: one detect call at the reference input size, one recognise call per
    //   box in reference order, and group_rows on the kept boxes.
    // implication: AC8 — on-device output can only be trusted if the Dart glue
    //   around the models is the measured reference.

    late Map<String, dynamic> fixture;
    late Float32List prob;
    late RgbImage image;

    setUpAll(() {
      const dir = 'test/fixtures/receipt_ocr';
      fixture = jsonDecode(File('$dir/synthetic.json').readAsStringSync()) as Map<String, dynamic>;
      final q = gzip.decode(File('$dir/det_prob_u8.bin.gz').readAsBytesSync());
      prob = Float32List.fromList([for (final v in q) v / 255.0]);
      image = decodeRgbImage(File('$dir/synthetic.png').readAsBytesSync())!;
    });

    test('decodeRgbImage reads the fixture size', () {
      expect((image.width, image.height), (fixture['image_w'], fixture['image_h']));
    });

    test('text lines, detector call and recogniser calls match', () async {
      final runner = _FixtureRunner(fixture, prob);
      final dict = parseRecDict(File('assets/ocr/rec_dict.txt').readAsStringSync());
      final lines = await readReceiptLines(image, runner, dict, batchSize: 1);

      expect(lines, (fixture['lines'] as List).cast<String>());

      expect(runner.detCalls.length, 1);
      final (h, w, detSum) = runner.detCalls.single;
      expect((h, w), (fixture['det_h'], fixture['det_w']));
      final expectedDet = (fixture['det_input_sum'] as num).toDouble();
      expect(detSum, closeTo(expectedDet, expectedDet.abs() * 1e-4));

      final boxes = (fixture['boxes'] as List).cast<Map<String, dynamic>>();
      expect({for (final c in runner.recCalls) c.$1}, {for (var i = 0; i < boxes.length; i++) i});
      for (final (i, recW, recSum) in runner.recCalls) {
        expect(recW, boxes[i]['rec_w'], reason: 'box $i width');
        final expectedRec = (boxes[i]['rec_input_sum'] as num).toDouble();
        expect(recSum, closeTo(expectedRec, expectedRec.abs() * 1e-3 + 1), reason: 'box $i crop');
      }
    });

    test('[EQUIV] batched recogniser gives the reference lines', () async {
      // testTheory: equivalence — batching and width-sorting change call shape,
      //   not the decoded text.
      // contract: default batchSize (8) yields the fixture lines and recognises
      //   every box exactly once.
      // implication: spec receipt_queue AC4 — batched recognition is a speed
      //   change only.
      final runner = _FixtureRunner(fixture, prob);
      final dict = parseRecDict(File('assets/ocr/rec_dict.txt').readAsStringSync());
      final lines = await readReceiptLines(image, runner, dict);

      expect(lines, (fixture['lines'] as List).cast<String>());
      final boxes = (fixture['boxes'] as List).cast<Map<String, dynamic>>();
      final seen = [for (final c in runner.recCalls) c.$1]..sort();
      expect(seen, [for (var i = 0; i < boxes.length; i++) i]);
    });
  });
}
