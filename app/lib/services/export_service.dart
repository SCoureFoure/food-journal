import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'storage_service.dart';

class ExportService {
  final StorageService _storage;

  ExportService(this._storage);

  Future<void> exportMealsJson({DateTime? from, DateTime? to}) async {
    final meals = await _storage.getMealsInRange(from: from, to: to);

    final mealsList = <Map<String, dynamic>>[];
    for (final meal in meals) {
      final foodItems = await _storage.getFoodItemsForMeal(meal.id!);
      final itemsList = <Map<String, dynamic>>[];

      for (final item in foodItems) {
        final ingredients = await _storage.getIngredientsForFoodItem(item.id!);
        itemsList.add({
          'name': item.name,
          'portion': item.portion,
          'prep': item.prep,
          'calories': item.calories,
          'protein': item.protein,
          'carbs': item.carbs,
          'fat': item.fat,
          'reaction': item.reaction.name,
          'notes': item.notes,
          'ingredients': ingredients
              .map((i) => {
                    'name': i.name,
                    'quantity': i.quantity,
                    'unit': i.unit,
                  })
              .toList(),
        });
      }

      final reactionLogs = await _storage.getReactionLogsForMeal(meal.id!);
      mealsList.add({
        'date': meal.date.toIso8601String().split('T').first,
        'time': meal.time,
        'meal_type': meal.mealType,
        'overall_symptoms': meal.overallSymptoms,
        'raw_input': meal.rawInput,
        'created_at': meal.createdAt.toIso8601String(),
        'image_data': meal.imageData != null ? base64Encode(meal.imageData!) : null,
        'food_items': itemsList,
        'reaction_logs': reactionLogs
            .map((r) => {
                  'checkin_time': r.checkinTime.toIso8601String(),
                  'symptoms': r.symptoms,
                  'severity': r.severity.name,
                  'notes': r.notes,
                })
            .toList(),
      });
    }

    final foodMemories = await _storage.getFoodMemory();
    final payload = {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'date_range': {
        'from': from?.toIso8601String(),
        'to': to?.toIso8601String(),
      },
      'meals': mealsList,
      'food_memories': foodMemories
          .map((m) => {
                'food_name': m.foodName,
                'reaction_pattern': m.reactionPattern,
                'occurrences': m.occurrences,
                'last_seen': m.lastSeen.toIso8601String(),
                'flagged': m.flagged,
              })
          .toList(),
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/food_journal_$timestamp.json');
    await file.writeAsString(jsonStr);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Food Journal Export',
    );
  }
}
