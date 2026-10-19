/// Pure-Dart OCR primitives: a line-for-line port of the Python reference
/// `bakeoff/ref_ocr.py` (and `group_rows` from `run_ocr.py`).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// An 8-bit RGB image, row-major HWC; [data] has length width * height * 3.
class RgbImage {
  final int width;
  final int height;
  final Uint8List data;
  RgbImage(this.width, this.height, this.data);
}

/// Decodes [bytes], applies EXIF orientation and returns 3-channel RGB.
/// Returns null when the bytes are not a decodable image.
RgbImage? decodeRgbImage(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  final rgb = oriented.convert(format: img.Format.uint8, numChannels: 3);
  return RgbImage(
    rgb.width,
    rgb.height,
    Uint8List.fromList(rgb.getBytes(order: img.ChannelOrder.rgb)),
  );
}

int _round32(double v) => math.max((v / 32 + 0.5).floor() * 32, 32);

/// Detector input size (height, width) for an image of [h] x [w].
(int, int) detResizeShape(int h, int w, {int limitSideLen = 736, int maxSideLen = 2000}) {
  if (math.max(h, w) > maxSideLen) {
    final s = maxSideLen / math.max(h, w);
    h = (h * s).toInt();
    w = (w * s).toInt();
  }
  final r = math.min(h, w) < limitSideLen ? limitSideLen / math.min(h, w) : 1.0;
  return (_round32(h * r), _round32(w * r));
}

/// HWC 3-channel values 0..255 to CHW values in -1..1.
Float32List normalizeChw(Float32List hwc, int h, int w) {
  final out = Float32List(3 * h * w);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      for (var c = 0; c < 3; c++) {
        out[c * h * w + y * w + x] = (hwc[(y * w + x) * 3 + c] / 255.0 - 0.5) / 0.5;
      }
    }
  }
  return out;
}

// Half-pixel centres: src = (dst + 0.5) * (in / out) - 0.5, clamped to the image.
({Int32List i0, Int32List i1, Float64List w}) _axisWeights(int nIn, int nOut) {
  final i0 = Int32List(nOut);
  final i1 = Int32List(nOut);
  final w = Float64List(nOut);
  for (var d = 0; d < nOut; d++) {
    final src = ((d + 0.5) * (nIn / nOut) - 0.5).clamp(0.0, nIn - 1.0);
    final f = src.floor();
    i0[d] = f;
    i1[d] = math.min(f + 1, nIn - 1);
    w[d] = src - f;
  }
  return (i0: i0, i1: i1, w: w);
}

/// Separable bilinear resize of an HWC float image with [channels] channels.
Float32List resizeBilinear(Float32List src, int inH, int inW, int channels, int outH, int outW) {
  final ys = _axisWeights(inH, outH);
  final xs = _axisWeights(inW, outW);
  final out = Float32List(outH * outW * channels);
  for (var y = 0; y < outH; y++) {
    final wy = ys.w[y];
    final r0 = ys.i0[y] * inW;
    final r1 = ys.i1[y] * inW;
    for (var x = 0; x < outW; x++) {
      final wx = xs.w[x];
      final x0 = xs.i0[x];
      final x1 = xs.i1[x];
      for (var c = 0; c < channels; c++) {
        final a = src[(r0 + x0) * channels + c] * (1 - wy) + src[(r1 + x0) * channels + c] * wy;
        final b = src[(r0 + x1) * channels + c] * (1 - wy) + src[(r1 + x1) * channels + c] * wy;
        out[(y * outW + x) * channels + c] = a * (1 - wx) + b * wx;
      }
    }
  }
  return out;
}

/// Grows set pixels one step toward the bottom and right (0/1 values).
Uint8List dilate2x2(Uint8List b, int h, int w) {
  final out = Uint8List.fromList(b);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (b[y * w + x] == 0) continue;
      if (y + 1 < h) out[(y + 1) * w + x] = 1;
      if (x + 1 < w) out[y * w + x + 1] = 1;
      if (y + 1 < h && x + 1 < w) out[(y + 1) * w + x + 1] = 1;
    }
  }
  return out;
}

/// 8-connected components of set pixels, as flat indices y * w + x, ordered by
/// each component's first pixel in row-major scan.
List<List<int>> components(Uint8List b, int h, int w) {
  final seen = Uint8List(h * w);
  final comps = <List<int>>[];
  for (var s = 0; s < h * w; s++) {
    if (b[s] == 0 || seen[s] != 0) continue;
    seen[s] = 1;
    final stack = <int>[s];
    final comp = <int>[];
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      comp.add(p);
      final y = p ~/ w;
      final x = p % w;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final ny = y + dy;
          final nx = x + dx;
          if (ny < 0 || ny >= h || nx < 0 || nx >= w) continue;
          final n = ny * w + nx;
          if (b[n] != 0 && seen[n] == 0) {
            seen[n] = 1;
            stack.add(n);
          }
        }
      }
    }
    comps.add(comp);
  }
  return comps;
}

int _cmpPoint((double, double) a, (double, double) b) =>
    a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2);

double _cross((double, double) o, (double, double) a, (double, double) b) =>
    (a.$1 - o.$1) * (b.$2 - o.$2) - (a.$2 - o.$2) * (b.$1 - o.$1);

/// Andrew monotone chain; collinear points are dropped.
List<(double, double)> convexHull(List<(double, double)> points) {
  final sorted = [...points]..sort(_cmpPoint);
  final pts = <(double, double)>[];
  for (final p in sorted) {
    if (pts.isEmpty || _cmpPoint(pts.last, p) != 0) pts.add(p);
  }
  if (pts.length <= 2) return pts;

  final lower = <(double, double)>[];
  for (final p in pts) {
    while (lower.length >= 2 && _cross(lower[lower.length - 2], lower.last, p) <= 0) {
      lower.removeLast();
    }
    lower.add(p);
  }
  final upper = <(double, double)>[];
  for (final p in pts.reversed) {
    while (upper.length >= 2 && _cross(upper[upper.length - 2], upper.last, p) <= 0) {
      upper.removeLast();
    }
    upper.add(p);
  }
  return [...lower.take(lower.length - 1), ...upper.take(upper.length - 1)];
}

// Smallest key wins; ties go to the smaller x.
(double, double) _pick(List<(double, double)> c, double Function((double, double)) key) {
  var best = c.first;
  for (final p in c.skip(1)) {
    final kp = key(p);
    final kb = key(best);
    if (kp < kb || (kp == kb && p.$1 < best.$1)) best = p;
  }
  return best;
}

List<(double, double)> _orderCorners(List<(double, double)> c) => [
      _pick(c, (p) => p.$1 + p.$2),
      _pick(c, (p) => p.$2 - p.$1),
      _pick(c, (p) => -(p.$1 + p.$2)),
      _pick(c, (p) => -(p.$2 - p.$1)),
    ];

double _dist((double, double) a, (double, double) b) => math.sqrt((b.$1 - a.$1) * (b.$1 - a.$1) + (b.$2 - a.$2) * (b.$2 - a.$2));

/// Minimum-area bounding rectangle via rotating calipers over hull edges.
/// Corners are ordered TL, TR, BR, BL; w = |TR-TL|, h = |BL-TL|.
({List<(double, double)> corners, double w, double h}) minAreaRect(List<(double, double)> points) {
  final hull = convexHull(points);
  List<(double, double)> raw;
  if (hull.length < 3) {
    var x0 = points.first.$1, x1 = x0, y0 = points.first.$2, y1 = y0;
    for (final p in points) {
      x0 = math.min(x0, p.$1);
      x1 = math.max(x1, p.$1);
      y0 = math.min(y0, p.$2);
      y1 = math.max(y1, p.$2);
    }
    raw = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)];
  } else {
    final n = hull.length;
    double bestArea = double.infinity;
    var bux = 0.0, buy = 0.0, bvx = 0.0, bvy = 0.0;
    var bu0 = 0.0, bu1 = 0.0, bv0 = 0.0, bv1 = 0.0;
    var found = false;
    for (var i = 0; i < n; i++) {
      final a = hull[i];
      final b = hull[(i + 1) % n];
      final ex = b.$1 - a.$1;
      final ey = b.$2 - a.$2;
      final ln = math.sqrt(ex * ex + ey * ey);
      final ux = ex / ln, uy = ey / ln;
      final vx = -uy, vy = ux;
      var u0 = double.infinity, u1 = -double.infinity;
      var v0 = double.infinity, v1 = -double.infinity;
      for (final p in hull) {
        final pu = p.$1 * ux + p.$2 * uy;
        final pv = p.$1 * vx + p.$2 * vy;
        u0 = math.min(u0, pu);
        u1 = math.max(u1, pu);
        v0 = math.min(v0, pv);
        v1 = math.max(v1, pv);
      }
      final area = (u1 - u0) * (v1 - v0);
      if (!found || area < bestArea) {
        found = true;
        bestArea = area;
        bux = ux; buy = uy; bvx = vx; bvy = vy;
        bu0 = u0; bu1 = u1; bv0 = v0; bv1 = v1;
      }
    }
    raw = [
      for (final (u, v) in [(bu0, bv0), (bu1, bv0), (bu1, bv1), (bu0, bv1)]) (u * bux + v * bvx, u * buy + v * bvy),
    ];
  }
  final corners = _orderCorners(raw);
  return (corners: corners, w: _dist(corners[0], corners[1]), h: _dist(corners[0], corners[3]));
}

/// Moves every corner outward by area * ratio / perimeter along the
/// rectangle's own edge directions.
({List<(double, double)> corners, double w, double h}) unclipRect(List<(double, double)> corners, {double ratio = 1.6}) {
  final tl = corners[0], tr = corners[1], bl = corners[3];
  final w = _dist(tl, tr);
  final h = _dist(tl, bl);
  final d = (w * h) * ratio / (2 * (w + h));
  final e1 = ((tr.$1 - tl.$1) / w, (tr.$2 - tl.$2) / w);
  final e2 = ((bl.$1 - tl.$1) / h, (bl.$2 - tl.$2) / h);
  const signs = [(-1, -1), (1, -1), (1, 1), (-1, 1)];
  final out = <(double, double)>[
    for (var i = 0; i < 4; i++)
      (
        corners[i].$1 + d * (signs[i].$1 * e1.$1 + signs[i].$2 * e2.$1),
        corners[i].$2 + d * (signs[i].$1 * e1.$2 + signs[i].$2 * e2.$2),
      ),
  ];
  return (corners: out, w: w + 2 * d, h: h + 2 * d);
}

/// Bilinear crop of the quad [corners] (TL, TR, BR, BL), border-clamped. Tall
/// crops (height / width >= 1.5) are rotated 90 degrees counter-clockwise.
/// A degenerate box yields an image with a zero dimension and no data.
RgbImage cropRotated(RgbImage img, List<(double, double)> corners) {
  final tl = corners[0], tr = corners[1], br = corners[2], bl = corners[3];
  final cw = math.max(_dist(tl, tr), _dist(bl, br)).toInt();
  final ch = math.max(_dist(tl, bl), _dist(tr, br)).toInt();
  final iw = img.width, ih = img.height;
  if (cw < 1 || ch < 1) return RgbImage(math.max(cw, 0), math.max(ch, 0), Uint8List(0));

  final out = Uint8List(cw * ch * 3);
  for (var v = 0; v < ch; v++) {
    for (var u = 0; u < cw; u++) {
      final sx = (tl.$1 + u * (tr.$1 - tl.$1) / cw + v * (bl.$1 - tl.$1) / ch).clamp(0.0, iw - 1.0);
      final sy = (tl.$2 + u * (tr.$2 - tl.$2) / cw + v * (bl.$2 - tl.$2) / ch).clamp(0.0, ih - 1.0);
      final x0 = sx.floor();
      final y0 = sy.floor();
      final x1 = math.min(x0 + 1, iw - 1);
      final y1 = math.min(y0 + 1, ih - 1);
      final fx = sx - x0;
      final fy = sy - y0;
      for (var c = 0; c < 3; c++) {
        final top = img.data[(y0 * iw + x0) * 3 + c] * (1 - fx) + img.data[(y0 * iw + x1) * 3 + c] * fx;
        final bot = img.data[(y1 * iw + x0) * 3 + c] * (1 - fx) + img.data[(y1 * iw + x1) * 3 + c] * fx;
        final val = top * (1 - fy) + bot * fy;
        out[(v * cw + u) * 3 + c] = (val + 0.5).floor().clamp(0, 255);
      }
    }
  }
  if (ch / cw < 1.5) return RgbImage(cw, ch, out);

  // np.rot90(k=1): new[y][x] = old[x][W-1-y]; new size is (W rows) x (H cols).
  final rot = Uint8List(out.length);
  for (var y = 0; y < cw; y++) {
    for (var x = 0; x < ch; x++) {
      final s = (x * cw + (cw - 1 - y)) * 3;
      final d = (y * ch + x) * 3;
      rot[d] = out[s];
      rot[d + 1] = out[s + 1];
      rot[d + 2] = out[s + 2];
    }
  }
  return RgbImage(ch, cw, rot);
}

/// Recogniser input: [crop] resized to 48 high, normalised, CHW, right-padded
/// with 0.0 to a width of at least 320.
({Float32List data, int width}) recInput(RgbImage crop) {
  final ch = crop.height, cw = crop.width;
  final rw = (48 * cw / ch).ceil();
  final resized = resizeBilinear(Float32List.fromList([for (final v in crop.data) v.toDouble()]), ch, cw, 3, 48, rw);
  final norm = normalizeChw(resized, 48, rw);
  final width = math.max(320, rw);
  final out = Float32List(3 * 48 * width);
  for (var c = 0; c < 3; c++) {
    for (var y = 0; y < 48; y++) {
      for (var x = 0; x < rw; x++) {
        out[(c * 48 + y) * width + x] = norm[(c * 48 + y) * rw + x];
      }
    }
  }
  return (data: out, width: width);
}

/// Greedy CTC decode of [probs] (steps x classes, row-major). Returns the text
/// and the mean probability of the kept steps, or ('', 0.0) when none are kept.
(String, double) ctcDecode(Float32List probs, int steps, int classes, List<String> chars) {
  final full = ['blank', ...chars, ' '];
  final text = StringBuffer();
  var sum = 0.0;
  var count = 0;
  var prev = -1;
  for (var t = 0; t < steps; t++) {
    var best = 0;
    for (var c = 1; c < classes; c++) {
      if (probs[t * classes + c] > probs[t * classes + best]) best = c;
    }
    if (best != 0 && (t == 0 || best != prev)) {
      text.write(full[best]);
      sum += probs[t * classes + best];
      count++;
    }
    prev = best;
  }
  if (count == 0) return ('', 0.0);
  return (text.toString(), sum / count);
}

/// Joins recognised [texts] into lines by vertical position of their [boxes].
String groupRows(List<List<(double, double)>> boxes, List<String> texts) {
  if (boxes.isEmpty) return '';
  final items = <({double yc, double h, double minX, String text, int i})>[];
  for (var i = 0; i < math.min(boxes.length, texts.length); i++) {
    final ys = [for (final p in boxes[i]) p.$2];
    final xs = [for (final p in boxes[i]) p.$1];
    items.add((
      yc: ys.fold(0.0, (a, b) => a + b) / 4,
      h: ys.reduce(math.max) - ys.reduce(math.min),
      minX: xs.reduce(math.min),
      text: texts[i],
      i: i,
    ));
  }
  final hs = [for (final it in items) it.h]..sort();
  final mid = hs.length ~/ 2;
  final medianH = hs.length.isOdd ? hs[mid] : (hs[mid - 1] + hs[mid]) / 2;

  items.sort((a, b) => a.yc != b.yc ? a.yc.compareTo(b.yc) : a.i.compareTo(b.i));
  final rows = <List<({double yc, double h, double minX, String text, int i})>>[];
  for (final it in items) {
    if (rows.isNotEmpty) {
      final cur = rows.last;
      final rowMeanYc = cur.fold(0.0, (a, c) => a + c.yc) / cur.length;
      if ((it.yc - rowMeanYc).abs() <= 0.5 * medianH) {
        cur.add(it);
        continue;
      }
    }
    rows.add([it]);
  }
  return [
    for (final row in rows)
      (row..sort((a, b) => a.minX != b.minX ? a.minX.compareTo(b.minX) : a.i.compareTo(b.i)))
          .map((it) => it.text)
          .join(' '),
  ].join('\n');
}

/// Greedy CTC decode from per-step argmax [idx] and max probability [maxp] (same
/// length). Same result as [ctcDecode] on the full scores.
(String, double) ctcDecodeArgmax(List<int> idx, List<double> maxp, List<String> chars) {
  final full = ['blank', ...chars, ' '];
  final text = StringBuffer();
  var sum = 0.0;
  var count = 0;
  for (var t = 0; t < idx.length; t++) {
    if (idx[t] != 0 && (t == 0 || idx[t] != idx[t - 1])) {
      text.write(full[idx[t]]);
      sum += maxp[t];
      count++;
    }
  }
  if (count == 0) return ('', 0.0);
  return (text.toString(), sum / count);
}

/// Batch plan for recogniser inputs of the given [widths]: indices sorted by width
/// ascending (ties keep input order), cut into chunks of at most [batchSize].
List<List<int>> recBatches(List<int> widths, {int batchSize = 8}) {
  if (batchSize < 1) throw ArgumentError.value(batchSize, 'batchSize', 'must be at least 1');
  final order = [for (var i = 0; i < widths.length; i++) i]
    ..sort((a, b) => widths[a] != widths[b] ? widths[a].compareTo(widths[b]) : a.compareTo(b));
  return [
    for (var s = 0; s < order.length; s += batchSize)
      order.sublist(s, math.min(s + batchSize, order.length)),
  ];
}

/// Stacks recogniser inputs (each CHW 3x48x[width]) into one NCHW tensor, each item
/// right-padded with 0.0 to the widest one.
({Float32List data, int n, int width}) stackRecInputs(List<({Float32List data, int width})> inputs) {
  if (inputs.isEmpty) throw ArgumentError.value(inputs, 'inputs', 'must not be empty');
  final n = inputs.length;
  final width = inputs.map((e) => e.width).reduce(math.max);
  final out = Float32List(n * 3 * 48 * width);
  for (var i = 0; i < n; i++) {
    final inp = inputs[i];
    for (var c = 0; c < 3; c++) {
      for (var y = 0; y < 48; y++) {
        for (var x = 0; x < inp.width; x++) {
          out[((i * 3 + c) * 48 + y) * width + x] = inp.data[(c * 48 + y) * inp.width + x];
        }
      }
    }
  }
  return (data: out, n: n, width: width);
}
