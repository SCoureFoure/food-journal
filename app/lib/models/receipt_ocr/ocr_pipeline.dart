/// Receipt OCR glue: detector -> boxes -> recogniser -> text lines. Port of
/// `ref_ocr.ocr_image` steps 2-5; the models themselves sit behind [OcrModelRunner].
library;

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;

import 'ocr_ops.dart';

/// Recogniser output for a batch: per-step argmax class and its probability,
/// [n] x [steps] row-major.
class RecBatchOutput {
  final List<int> idx;
  final List<double> maxp;
  final int steps;
  const RecBatchOutput(this.idx, this.maxp, this.steps);
}

/// Runs the detector and recogniser models.
abstract class OcrModelRunner {
  /// [input] is NCHW [1,3,h,w]; returns the [h*w] probability map, row-major.
  Future<Float32List> detect(Float32List input, int h, int w);

  /// [input] is NCHW [n,3,48,w]; returns per-step argmax and max probability.
  Future<RecBatchOutput> recognizeBatch(Float32List input, int n, int w);
}

typedef _Box = List<(double, double)>;
typedef _RecBatch = (List<int> order, Float32List data, int n, int width);

(Float32List, int, int) _prepDetect(RgbImage image) {
  final (nh, nw) = detResizeShape(image.height, image.width);
  final resized = resizeBilinear(
    Float32List.fromList([for (final v in image.data) v.toDouble()]),
    image.height,
    image.width,
    3,
    nh,
    nw,
  );
  return (normalizeChw(resized, nh, nw), nh, nw);
}

({List<_Box> boxes, List<_RecBatch> batches}) _prepRecognize(
  ({RgbImage image, Float32List prob, int nh, int nw, int batchSize}) args,
) {
  final image = args.image, prob = args.prob, nh = args.nh, nw = args.nw;
  final width = image.width, height = image.height;

  // The reference compares a float32 map against a float32 threshold.
  final threshold = Float32List.fromList([0.3])[0];
  final binary = Uint8List(nh * nw);
  for (var i = 0; i < binary.length; i++) {
    if (prob[i] > threshold) binary[i] = 1;
  }
  final dilated = dilate2x2(binary, nh, nw);

  final boxes = <_Box>[];
  for (final comp in components(dilated, nh, nw).take(1000)) {
    var sum = 0.0;
    for (final p in comp) {
      sum += prob[p];
    }
    if (sum / comp.length < 0.5) continue;
    var rect = minAreaRect([for (final p in comp) ((p % nw).toDouble(), (p ~/ nw).toDouble())]);
    if (rect.w < rect.h ? rect.w < 3 : rect.h < 3) continue;
    rect = unclipRect(rect.corners, ratio: 1.6);
    if (rect.w < rect.h ? rect.w < 5 : rect.h < 5) continue;
    boxes.add([
      for (final (cx, cy) in rect.corners)
        (
          (cx * (width / nw)).clamp(0.0, width - 1.0).toDouble(),
          (cy * (height / nh)).clamp(0.0, height - 1.0).toDouble(),
        ),
    ]);
  }

  final keptBoxes = <_Box>[];
  final inputs = <({Float32List data, int width})>[];
  for (final box in boxes) {
    final crop = cropRotated(image, box);
    if (crop.width < 1 || crop.height < 1) continue;
    final input = recInput(crop);
    keptBoxes.add(box);
    inputs.add((data: input.data, width: input.width));
  }

  final batches = <_RecBatch>[];
  for (final order in recBatches([for (final i in inputs) i.width], batchSize: args.batchSize)) {
    final stacked = stackRecInputs([for (final i in order) inputs[i]]);
    batches.add((order, stacked.data, stacked.n, stacked.width));
  }
  return (boxes: keptBoxes, batches: batches);
}

/// Reads the text lines of a receipt [image] using [runner] and the
/// recogniser dictionary [chars]. Returns [] when no text is found.
Future<List<String>> readReceiptLines(
  RgbImage image,
  OcrModelRunner runner,
  List<String> chars, {
  int batchSize = 8,
}) async {
  final det = await compute(_prepDetect, image);
  final (detInput, nh, nw) = det;
  final prob = await runner.detect(detInput, nh, nw);

  final rec = await compute(_prepRecognize, (image: image, prob: prob, nh: nh, nw: nw, batchSize: batchSize));

  final texts = List<(String, double)>.filled(rec.boxes.length, ('', 0.0));
  for (final (order, data, n, width) in rec.batches) {
    final out = await runner.recognizeBatch(data, n, width);
    final steps = out.steps;
    for (var r = 0; r < n; r++) {
      texts[order[r]] = ctcDecodeArgmax(
        out.idx.sublist(r * steps, (r + 1) * steps),
        out.maxp.sublist(r * steps, (r + 1) * steps),
        chars,
      );
    }
  }

  final keptBoxes = <_Box>[];
  final keptTexts = <String>[];
  for (var i = 0; i < rec.boxes.length; i++) {
    final (text, score) = texts[i];
    if (score >= 0.5 && text.trim().isNotEmpty) {
      keptBoxes.add(rec.boxes[i]);
      keptTexts.add(text);
    }
  }
  if (keptBoxes.isEmpty) return [];
  return groupRows(keptBoxes, keptTexts).split('\n');
}
