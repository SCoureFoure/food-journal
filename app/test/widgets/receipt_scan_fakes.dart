import 'dart:typed_data';

import 'package:food_journal/models/pantry_item.dart';
import 'package:food_journal/models/receipt_parser.dart';
import 'package:food_journal/services/ai_service.dart';
import 'package:food_journal/services/receipt_ocr_service.dart';
import 'package:food_journal/services/storage_service.dart';

/// In-memory pantry. The DB handle in StorageService is lazy, so a subclass that
/// overrides every pantry method never opens sqlite.
class FakePantryStorage extends StorageService {
  final List<PantryItem> items = [];
  List<String> knownFoods = const [];
  int _nextId = 1;
  Object? addError;

  @override
  Future<List<PantryItem>> getPantryItems() async {
    final sorted = [...items]
      ..sort((a, b) {
        final t = b.addedAt.compareTo(a.addedAt);
        return t != 0 ? t : b.id!.compareTo(a.id!);
      });
    return sorted;
  }

  @override
  Future<void> addPantryItems(List<PantryItem> add) async {
    if (addError != null) throw addError!;
    for (final p in add) {
      items.add(PantryItem(
        id: _nextId++,
        name: p.name,
        quantity: p.quantity,
        unit: p.unit,
        source: p.source,
        rawText: p.rawText,
        addedAt: p.addedAt,
      ));
    }
  }

  @override
  Future<void> deletePantryItem(int id) async => items.removeWhere((p) => p.id == id);

  @override
  Future<List<String>> getKnownFoodNames({int limit = 200}) async => knownFoods;
}

class FakeReceiptAi implements AiService {
  ReceiptParseResult result = ReceiptParseResult(success: true, items: const []);
  int calls = 0;
  String? lastText;
  List<String>? lastKnown;

  @override
  Future<ReceiptParseResult> parseReceipt(String ocrText, {List<String> knownFoods = const []}) async {
    calls++;
    lastText = ocrText;
    lastKnown = knownFoods;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeReceiptReader implements ReceiptReader {
  List<String> lines = const [];
  Object? error;
  int calls = 0;

  @override
  Future<List<String>> readLines(Uint8List imageBytes) async {
    calls++;
    if (error != null) throw error!;
    return lines;
  }
}

const hannafordLines = [
  'Hannaford',
  'PRODUCE',
  'LIMES W 0.59',
  'GROCERY',
  'PROG TRD CHK ORZ LMN 2.50',
  'PROG TRD CHK ORZ LMN 2.50',
  'HEALTH & BEAUTY',
  'DVE MEN+CARE CDRWD/T 10.49',
  'BALANCE DUE 16.08',
  'VISA 3319',
];

List<ParsedReceiptItem> hannafordItems() =>
    mergeReceiptItems(parseReceiptText(hannafordLines.join('\n')));
