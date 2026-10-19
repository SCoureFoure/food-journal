/// Deterministic receipt OCR-text parser. See specs/receipt_scan.spec.md.
library;

/// One line item read from receipt text. [food] is null when the parser could
/// not tell; [name] is a generic food name supplied only by the AI layer.
class ParsedReceiptItem {
  final String raw;     // item text as printed, price/flags stripped
  final double qty;
  final String unit;    // 'ea' | 'lb'
  final bool? food;     // null = unknown
  final String? name;   // generic food name (AI only); parser leaves null

  const ParsedReceiptItem({required this.raw, this.qty = 1, this.unit = 'ea', this.food, this.name});

  Map<String, dynamic> toJson() => {'raw': raw, 'qty': qty, 'unit': unit, 'food': food, 'name': name};

  /// Inverse of [toJson]. Throws [FormatException] on a missing or mistyped field.
  factory ParsedReceiptItem.fromJson(Map<String, dynamic> j) {
    final raw = j['raw'];
    final qty = j['qty'];
    final unit = j['unit'];
    final food = j['food'];
    final name = j['name'];
    if (raw is! String ||
        qty is! num ||
        unit is! String ||
        (food != null && food is! bool) ||
        (name != null && name is! String)) {
      throw const FormatException('bad receipt item');
    }
    return ParsedReceiptItem(
      raw: raw,
      qty: qty.toDouble(),
      unit: unit,
      food: food as bool?,
      name: name as String?,
    );
  }

  /// Copy with the given fields replaced. Fields cannot be reset to null.
  ParsedReceiptItem copyWith({String? raw, double? qty, String? unit, bool? food, String? name}) {
    return ParsedReceiptItem(
      raw: raw ?? this.raw,
      qty: qty ?? this.qty,
      unit: unit ?? this.unit,
      food: food ?? this.food,
      name: name ?? this.name,
    );
  }
}

const List<String> _sections = [
  'BAKERY', 'DELI', 'GROCERY', 'PRODUCE', 'MEAT', 'SEAFOOD', 'DAIRY', 'FROZEN',
  'GENERAL MDSE', 'HEALTH & BEAUTY', 'BEER & WINE', 'FLORAL', 'PHARMACY', 'HOUSEHOLD', 'PET',
];
const Set<String> _nonFood = {'GENERAL MDSE', 'HEALTH & BEAUTY', 'HOUSEHOLD', 'PET', 'PHARMACY'};

final RegExp _weightRe = RegExp(r'^(\d+\.\d+)\s*(LB|1B|IB|L8)\s*@');
final RegExp _countRe = RegExp(r'^(\d+)\s*@');
final RegExp _priceTokenRe = RegExp(r'^\d+\.\d{2}$');
final RegExp _totalRe = RegExp(r'^(SUB ?)?TOTAL \d+\.\d{2}$');

/// Uppercases [s], keeps only receipt-safe characters, and collapses spaces.
String normalizeReceiptLine(String s) {
  return s
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9 .&+/@\-]'), ' ')
      .replaceAll(RegExp(' +'), ' ')
      .trim();
}

/// Port of Python difflib.SequenceMatcher(None, a, b).ratio().
double sequenceRatio(String a, String b) {
  final total = a.length + b.length;
  if (total == 0) return 1.0;
  return 2 * _matchedChars(a, 0, a.length, b, 0, b.length) / total;
}

int _matchedChars(String a, int alo, int ahi, String b, int blo, int bhi) {
  var bestI = alo;
  var bestJ = blo;
  var bestK = 0;
  for (var i = alo; i < ahi; i++) {
    for (var j = blo; j < bhi; j++) {
      var k = 0;
      while (i + k < ahi && j + k < bhi && a[i + k] == b[j + k]) {
        k++;
      }
      if (k > bestK) {
        bestI = i;
        bestJ = j;
        bestK = k;
      }
    }
  }
  if (bestK == 0) return 0;
  return bestK +
      _matchedChars(a, alo, bestI, b, blo, bestJ) +
      _matchedChars(a, bestI + bestK, ahi, b, bestJ + bestK, bhi);
}

bool _isEnd(String line) {
  return line.contains('BALANCE DUE') ||
      line.contains('TAX PAID') ||
      line.startsWith('TAX ') ||
      _totalRe.hasMatch(line);
}

/// Applies quantity lines, item-length filtering, and token stripping to one
/// normalized, non-empty line. [food] is the flag stamped on any new item.
void _consumeLine(String line, bool? food, List<ParsedReceiptItem> items) {
  if (line.contains('@')) {
    if (items.isNotEmpty) {
      final weight = _weightRe.firstMatch(line);
      final count = _countRe.firstMatch(line);
      if (weight != null) {
        items[items.length - 1] = items.last.copyWith(
          qty: double.parse(weight.group(1)!),
          unit: 'lb',
        );
      } else if (count != null) {
        items[items.length - 1] = items.last.copyWith(
          qty: double.parse(count.group(1)!),
          unit: 'ea',
        );
      }
    }
    return;
  }
  if (RegExp('[A-Z]').allMatches(line).length < 3) return;
  final tokens = line.split(' ');
  while (tokens.isNotEmpty &&
      (_priceTokenRe.hasMatch(tokens.last) || tokens.last == 'B' || tokens.last == 'W')) {
    tokens.removeLast();
  }
  items.add(ParsedReceiptItem(raw: tokens.join(' '), food: food));
}

/// Header-driven pass. Returns null when no section header was seen.
List<ParsedReceiptItem>? _parseWithHeaders(List<String> lines) {
  final items = <ParsedReceiptItem>[];
  String? section;
  for (final rawLine in lines) {
    final line = normalizeReceiptLine(rawLine);
    if (line.isEmpty) continue;
    if (section != null && _isEnd(line)) break;

    var best = _sections.first;
    var bestRatio = sequenceRatio(line, best);
    for (final s in _sections.skip(1)) {
      final r = sequenceRatio(line, s);
      if (r > bestRatio) {
        best = s;
        bestRatio = r;
      }
    }
    if (bestRatio >= 0.80) {
      section = best;
      continue;
    }

    if (section == null) continue;
    _consumeLine(line, !_nonFood.contains(section), items);
  }
  if (section == null) return null;
  return items;
}

/// Fallback pass for text with no headers. Food status is always unknown.
List<ParsedReceiptItem> _parseHeaderless(List<String> lines) {
  final items = <ParsedReceiptItem>[];
  var started = false;
  for (final rawLine in lines) {
    final line = normalizeReceiptLine(rawLine);
    if (line.isEmpty) continue;
    if (!started) {
      if (!_priceTokenRe.hasMatch(line.split(' ').last)) continue;
      started = true;
    }
    if (_isEnd(line)) break;
    _consumeLine(line, null, items);
  }
  return items;
}

/// Parses OCR receipt text into line items.
List<ParsedReceiptItem> parseReceiptText(String text) {
  final lines = text.split('\n');
  return _parseWithHeaders(lines) ?? _parseHeaderless(lines);
}

double _round3(double x) => (x * 1000).round() / 1000;

/// Merges rows with the same raw text and unit, summing quantities in
/// first-seen order. Food and name come from the first row.
List<ParsedReceiptItem> mergeReceiptItems(List<ParsedReceiptItem> items) {
  final merged = <String, ParsedReceiptItem>{};
  for (final item in items) {
    final key = '${item.raw}\u0000${item.unit}';
    final existing = merged[key];
    merged[key] = existing == null
        ? item
        : existing.copyWith(qty: _round3(existing.qty + item.qty));
  }
  return merged.values.toList();
}

/// Returns the receipt text up to and including the first end-of-items line
/// (BALANCE DUE, or SUBTOTAL / TOTAL followed by a price). Returns [text] unchanged if none.
String receiptItemRegion(String text) {
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = normalizeReceiptLine(lines[i]);
    if (line.contains('BALANCE DUE') || _totalRe.hasMatch(line)) {
      return lines.sublist(0, i + 1).join('\n');
    }
  }
  return text;
}

/// Text sent to the Worker's `parse_receipt` task: the item region only, prefixed
/// with the user's known food names when there are any.
String buildReceiptAiText(String ocrText, List<String> knownFoods) {
  final region = receiptItemRegion(ocrText);
  if (knownFoods.isEmpty) return region;
  return 'Known foods:\n${knownFoods.join('\n')}\n\n$region';
}
