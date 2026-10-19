/// Receipt OCR glue: detector -> boxes -> recogniser -> text lines. Port of
/// `ref_ocr.ocr_image` steps 2-5; the models themselves sit behind [OcrModelRunner].
library;

import 'dart:typed_data';

import 'ocr_ops.dart';

/// Raw recogniser output: [steps] x [classes] probabilities, row-major.
class RecOutput {
  final Float32List probs;
  final int steps;
  final int classes;
  const RecOutput(this.probs, this.steps, this.classes);
}

/// Runs the detector and recogniser models.
abstract class OcrModelRunner {
  /// [input] is NCHW [1,3,h,w]; returns the [h*w] probability map, row-major.
  Future<Float32List> detect(Float32List input, int h, int w);

  /// [input] is NCHW [1,3,48,w]; returns probabilities [steps*classes].
  Future<RecOutput> recognize(Float32List input, int w);
}

/// Reads the text lines of a receipt [image] using [runner] and the
/// recogniser dictionary [chars]. Returns [] when no text is found.
Future<List<String>> readReceiptLines(RgbImage image, OcrModelRunner runner, List<String> chars) async {
  final width = image.width, height = image.height;
  final (nh, nw) = detResizeShape(height, width);
  final resized = resizeBilinear(
    Float32List.fromList([for (final v in image.data) v.toDouble()]),
    height,
    width,
    3,
    nh,
    nw,
  );
  final prob = await runner.detect(normalizeChw(resized, nh, nw), nh, nw);

  // The reference compares a float32 map against a float32 threshold.
  final threshold = Float32List.fromList([0.3])[0];
  final binary = Uint8List(nh * nw);
  for (var i = 0; i < binary.length; i++) {
    if (prob[i] > threshold) binary[i] = 1;
  }
  final dilated = dilate2x2(binary, nh, nw);

  final boxes = <List<(double, double)>>[];
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

  final keptBoxes = <List<(double, double)>>[];
  final keptTexts = <String>[];
  for (final box in boxes) {
    final crop = cropRotated(image, box);
    if (crop.width < 1 || crop.height < 1) continue;
    final input = recInput(crop);
    final out = await runner.recognize(input.data, input.width);
    final (text, score) = ctcDecode(out.probs, out.steps, out.classes, chars);
    if (score >= 0.5 && text.trim().isNotEmpty) {
      keptBoxes.add(box);
      keptTexts.add(text);
    }
  }
  if (keptBoxes.isEmpty) return [];
  return groupRows(keptBoxes, keptTexts).split('\n');
}
