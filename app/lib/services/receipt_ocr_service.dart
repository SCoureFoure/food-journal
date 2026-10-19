import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import '../models/receipt_ocr/ocr_ops.dart';
import '../models/receipt_ocr/ocr_pipeline.dart';

/// Reads receipt photos into text lines. Widgets depend on this, so tests can fake it.
abstract class ReceiptReader {
  /// Text lines top to bottom. Empty list when nothing is readable. Throws
  /// [ReceiptReadException] when the image cannot be decoded or a model fails.
  Future<List<String>> readLines(Uint8List imageBytes);
}

/// Thrown by [ReceiptReader] when a photo or model cannot be read.
class ReceiptReadException implements Exception {
  final String message;
  const ReceiptReadException(this.message);
  @override
  String toString() => message;
}

/// On-device PaddleOCR via ONNX Runtime. Sessions load lazily on first use and are kept.
class OnnxReceiptReader implements ReceiptReader, OcrModelRunner {
  static const detAsset = 'assets/ocr/PP-OCRv6_det_small.onnx';
  static const recAsset = 'assets/ocr/PP-OCRv6_rec_small_argmax.onnx';
  static const dictAsset = 'assets/ocr/rec_dict.txt';

  late OrtSession _det;
  late OrtSession _rec;
  late List<String> _chars;
  Future<void>? _ready;

  Future<void> _ensureReady() => _ready ??= _load();

  Future<void> _load() async {
    final ort = OnnxRuntime();
    final options = OrtSessionOptions(intraOpNumThreads: 4);
    _det = await ort.createSessionFromAsset(detAsset, options: options);
    _rec = await ort.createSessionFromAsset(recAsset, options: options);
    final chars = (await rootBundle.loadString(dictAsset)).split('\n');
    if (chars.isNotEmpty && chars.last.isEmpty) chars.removeLast();
    _chars = chars;
  }

  @override
  Future<List<String>> readLines(Uint8List imageBytes) async {
    try {
      final image = await compute(decodeRgbImage, imageBytes);
      if (image == null) throw const ReceiptReadException('Could not open that photo.');
      await _ensureReady();
      return await readReceiptLines(image, this, _chars);
    } on ReceiptReadException {
      rethrow;
    } catch (e) {
      throw ReceiptReadException('Could not read the receipt: $e');
    }
  }

  @override
  Future<Float32List> detect(Float32List input, int h, int w) async {
    final (data, _) = await _run(_det, input, [1, 3, h, w]);
    if (data.length != h * w) {
      throw const ReceiptReadException('Detector returned an unexpected size.');
    }
    return data;
  }

  @override
  Future<RecBatchOutput> recognizeBatch(Float32List input, int n, int w) async {
    final x = await OrtValue.fromList(input, [n, 3, 48, w]);
    Map<String, OrtValue>? out;
    try {
      out = await _rec.run({'x': x});
      final idxFlat = await out['idx']!.asFlattenedList();
      final maxpFlat = await out['maxp']!.asFlattenedList();
      final idx = [for (final e in idxFlat) (e as num).toInt()];
      final List<double> maxp = maxpFlat is Float32List
          ? maxpFlat
          : [for (final e in maxpFlat) (e as num).toDouble()];
      if (idx.length != maxp.length || idx.length % n != 0) {
        throw const ReceiptReadException('Recogniser returned an unexpected size.');
      }
      return RecBatchOutput(idx, maxp, idx.length ~/ n);
    } finally {
      await x.dispose();
      if (out != null) {
        for (final v in out.values) {
          await v.dispose();
        }
      }
    }
  }

  Future<(Float32List, List<int>)> _run(OrtSession session, Float32List input, List<int> shape) async {
    final x = await OrtValue.fromList(input, shape);
    Map<String, OrtValue>? out;
    try {
      out = await session.run({'x': x});
      final value = out.values.first;
      final flat = await value.asFlattenedList();
      final data = flat is Float32List
          ? flat
          : Float32List.fromList([for (final e in flat) (e as num).toDouble()]);
      return (data, value.shape);
    } finally {
      await x.dispose();
      if (out != null) {
        for (final v in out.values) {
          await v.dispose();
        }
      }
    }
  }
}
