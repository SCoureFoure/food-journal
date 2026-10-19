class PantryItem {
  final int? id;
  final String name;
  final double quantity;
  final String unit;     // 'ea' | 'lb'
  final String source;   // 'receipt' | 'manual'
  final String? rawText; // receipt line the item came from
  final DateTime addedAt;

  const PantryItem({
    this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.source,
    this.rawText,
    required this.addedAt,
  });
}

/// List label for a pantry quantity: counts as "×n", weights as "n lb". No trailing zeros.
String formatPantryQuantity(double quantity, String unit) {
  final String number;
  if (quantity == quantity.roundToDouble()) {
    number = quantity.toStringAsFixed(0);
  } else {
    number = quantity
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return unit == 'lb' ? '$number lb' : '×$number';
}
