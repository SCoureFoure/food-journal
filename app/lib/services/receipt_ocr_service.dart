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
  static const recAsset = 'assets/ocr/PP-OCRv6_rec_small.onnx';
  static const dictAsset = 'assets/ocr/rec_dict.txt';

  late OrtSession _det;
  late OrtSession _rec;
  late List<String> _chars;
  Future<void>? _ready;

  Future<void> _ensureReady() => _ready ??= _load();

  Future<void> _load() async {
    final ort = OnnxRuntime();
    _det = await ort.createSessionFromAsset(detAsset);
    _rec = await ort.createSessionFromAsset(recAsset);
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
  Future<RecOutput> recognize(Float32List input, int w) async {
    final (data, shape) = await _run(_rec, input, [1, 3, 48, w]);
    return RecOutput(data, shape[1], shape[2]);
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
