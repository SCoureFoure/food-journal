import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/receipt_ocr/ocr_ops.dart';

void main() {
  group('[EQUIV] argmax CTC decode and recogniser batching', () {
    // testTheory: equivalence — greedy decode from per-step argmax and max
    //   probability equals the full-score decode.
    // contract: ctcDecodeArgmax(argmax, maxp, chars) == ctcDecode(scores, ...)
    //   in text and mean score; all-blank input yields ('', 0.0).
    // implication: the recogniser can ship only argmax + maxprob across the
    //   model boundary without changing OCR text.

    test('ctcDecodeArgmax equals ctcDecode', () {
      const chars = ['a', 'b', 'c'];
      const argmax = [0, 1, 1, 0, 1, 2, 4, 3, 3];
      const classes = 5;
      final scores = Float32List(argmax.length * classes);
      for (var t = 0; t < argmax.length; t++) {
        final p = 0.9 - 0.01 * t;
        for (var c = 0; c < classes; c++) {
          scores[t * classes + c] = (1 - p) / 4;
        }
        scores[t * classes + argmax[t]] = p;
      }
      // Read back through Float32List so both decoders see identical values.
      final maxps = [for (var t = 0; t < argmax.length; t++) scores[t * classes + argmax[t]].toDouble()];

      final fast = ctcDecodeArgmax(argmax, maxps, chars);
      final full = ctcDecode(scores, argmax.length, classes, chars);
      expect(fast.$1, full.$1);
      expect(fast.$1, 'aab c');
      expect(fast.$2, closeTo(full.$2, 1e-9));
    });

    test('ctcDecodeArgmax on all-blank input is empty', () {
      expect(ctcDecodeArgmax(const [0, 0, 0], const [0.9, 0.9, 0.9], const ['a', 'b', 'c']), ('', 0.0));
    });

    test('recBatches sorts by width and chunks', () {
      // testTheory: minimum functionality — batch plan orders by width and chunks.
      // contract: indices ascending by width (stable), cut into batchSize chunks.
      // implication: similar-width crops share a batch, limiting padding waste.
      expect(recBatches(const [320, 700, 320, 500], batchSize: 2), const [
        [0, 2],
        [3, 1],
      ]);
      expect(recBatches(const [400, 320, 320]), const [
        [1, 2, 0],
      ]);
      expect(recBatches(const []), const <List<int>>[]);
      expect(() => recBatches(const [1], batchSize: 0), throwsArgumentError);
    });

    test('stackRecInputs pads with zeros', () {
      // testTheory: minimum functionality — NCHW stacking right-pads with 0.0.
      // contract: width = max input width; element (i,c,y,x) equals the input's
      //   value when x < its width, else 0.0.
      // implication: padded batch items must not change recogniser output
      //   relative to unbatched input.
      final a = (data: Float32List.fromList([for (var k = 0; k < 3 * 48 * 2; k++) (k + 1).toDouble()]), width: 2);
      final b = (data: Float32List(3 * 48 * 3)..fillRange(0, 3 * 48 * 3, 7.0), width: 3);
      final r = stackRecInputs([a, b]);
      expect(r.width, 3);
      expect(r.n, 2);
      expect(r.data.length, 2 * 3 * 48 * 3);

      expect(r.data[((0 * 3 + 1) * 48 + 5) * 3 + 1], a.data[(1 * 48 + 5) * 2 + 1]);
      for (var c = 0; c < 3; c++) {
        for (var y = 0; y < 48; y++) {
          expect(r.data[((0 * 3 + c) * 48 + y) * 3 + 2], 0.0, reason: 'A pad c=$c y=$y');
        }
      }
      for (var k = 3 * 48 * 3; k < r.data.length; k++) {
        expect(r.data[k], 7.0, reason: 'B element $k');
      }

      expect(() => stackRecInputs([]), throwsArgumentError);
    });
  });
}
