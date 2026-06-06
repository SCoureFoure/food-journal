import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/services/storage_service.dart';
import 'package:food_journal/models/food_item.dart';
import 'package:food_journal/models/ingredient.dart';
import 'package:food_journal/models/meal_entry.dart';
import 'package:food_journal/models/medication.dart';
import 'package:food_journal/models/reaction_log.dart';
import 'package:food_journal/services/export_service.dart';
import 'package:food_journal/services/import_service.dart';

// ─── Sample JSON ──────────────────────────────────────────────────────────────

const _sampleJson = '''
{
  "version": 2,
  "exported_at": "2026-05-14T10:00:00.000",
  "date_range": {"from": null, "to": null},
  "meals": [
    {
      "date": "2026-05-14",
      "time": "7:30 AM",
      "meal_type": "breakfast",
      "overall_symptoms": null,
      "raw_input": "eggs and toast",
      "created_at": "2026-05-14T07:30:00.000",
      "image_data": null,
      "food_items": [
        {
          "name": "Eggs",
          "portion": "2 whole",
          "prep": "scrambled",
          "calories": 180,
          "protein": 12,
          "carbs": 2,
          "fat": 13,
          "reaction": "none",
          "notes": null,
          "ingredients": [
            {"name": "eggs", "quantity": "2", "unit": "whole"},
            {"name": "butter", "quantity": "1", "unit": "tsp"}
          ]
        },
        {
          "name": "Toast",
          "portion": "1 slice",
          "prep": null,
          "calories": 80,
          "protein": 3,
          "carbs": 15,
          "fat": 1,
          "reaction": "none",
          "notes": null,
          "ingredients": []
        }
      ],
      "reaction_logs": [
        {
          "checkin_time": "2026-05-14T09:00:00.000",
          "symptoms": ["Bloating", "Fatigue"],
          "severity": "mild",
          "notes": "slight discomfort"
        }
      ]
    }
  ],
  "medications": [
    {
      "date": "2026-05-14",
      "time": "8:00 AM",
      "name": "Metformin",
      "dose": 500.0,
      "unit": "mg",
      "route": "oral",
      "checkin_delay_minutes": null,
      "raw_input": null,
      "notes": "with food",
      "created_at": "2026-05-14T08:00:00.000",
      "image_data": null
    }
  ],
  "food_memories": [
    {
      "food_name": "eggs",
      "reaction_pattern": "mild",
      "occurrences": 5,
      "last_seen": "2026-05-14T00:00:00.000",
      "flagged": false
    }
  ]
}
''';

void main() {
  // ─── ImportService.parseJson — happy path ─────────────────────────────────

  group('[MFT] ImportService.parseJson', () {
    test('parses version', () {
      final payload = ImportService.parseJson(_sampleJson);
      expect(payload.version, 2);
    });

    test('parses meal count and fields', () {
      final payload = ImportService.parseJson(_sampleJson);
      expect(payload.meals.length, 1);
      final record = payload.meals.first;
      expect(record.meal.mealType, 'breakfast');
      expect(record.meal.time, '7:30 AM');
      expect(record.meal.rawInput, 'eggs and toast');
      expect(record.meal.date, DateTime(2026, 5, 14));
    });

    test('parses food items', () {
      final payload = ImportService.parseJson(_sampleJson);
      final record = payload.meals.first;
      expect(record.foodItems.length, 2);
      expect(record.foodItems.first.name, 'Eggs');
      expect(record.foodItems.first.calories, 180);
      expect(record.foodItems.first.protein, 12);
      expect(record.foodItems.first.reaction, ReactionLevel.none);
      expect(record.foodItems[1].name, 'Toast');
    });

    test('parses ingredients', () {
      final payload = ImportService.parseJson(_sampleJson);
      final ings = payload.meals.first.ingredientsByItem.first;
      expect(ings.length, 2);
      expect(ings.first.name, 'eggs');
      expect(ings.first.quantity, '2');
      expect(ings.first.unit, 'whole');
      expect(payload.meals.first.ingredientsByItem[1], isEmpty);
    });

    test('parses reaction logs', () {
      final payload = ImportService.parseJson(_sampleJson);
      final logs = payload.meals.first.reactionLogs;
      expect(logs.length, 1);
      expect(logs.first.symptoms, containsAll(['Bloating', 'Fatigue']));
      expect(logs.first.severity, ReactionLevel.mild);
      expect(logs.first.notes, 'slight discomfort');
    });

    test('parses medications', () {
      final payload = ImportService.parseJson(_sampleJson);
      expect(payload.medications.length, 1);
      final med = payload.medications.first;
      expect(med.name, 'Metformin');
      expect(med.dose, 500.0);
      expect(med.unit, 'mg');
      expect(med.route, 'oral');
      expect(med.notes, 'with food');
    });

    test('parses food memories', () {
      final payload = ImportService.parseJson(_sampleJson);
      expect(payload.foodMemories.length, 1);
      final mem = payload.foodMemories.first;
      expect(mem.foodName, 'eggs');
      expect(mem.occurrences, 5);
      expect(mem.reactionPattern, 'mild');
      expect(mem.flagged, false);
    });

    test('dupe key is date|time|mealType|sorted-food-names', () {
      final payload = ImportService.parseJson(_sampleJson);
      final key = payload.meals.first.dupeKey;
      // food items: Eggs, Toast → sorted lowercase: eggs, toast
      expect(key, '2026-05-14|7:30 AM|breakfast|eggs,toast');
    });
  });

  // ─── ImportService.parseJson — edge inputs ────────────────────────────────

  group('[BVA] ImportService.parseJson — edge inputs', () {
    test('handles completely empty payload', () {
      final payload = ImportService.parseJson('{"version": 1}');
      expect(payload.version, 1);
      expect(payload.meals, isEmpty);
      expect(payload.medications, isEmpty);
      expect(payload.foodMemories, isEmpty);
    });

    test('handles unknown reaction name gracefully', () {
      final json = jsonEncode({
        'version': 2,
        'meals': [
          {
            'date': '2026-05-14',
            'time': '8am',
            'meal_type': 'lunch',
            'created_at': '2026-05-14T08:00:00.000',
            'food_items': [
              {
                'name': 'Mystery food',
                'reaction': 'unknown_reaction',
                'ingredients': [],
              }
            ],
            'reaction_logs': [],
          }
        ],
        'medications': [],
        'food_memories': [],
      });
      final payload = ImportService.parseJson(json);
      expect(payload.meals.first.foodItems.first.reaction, ReactionLevel.pending);
    });

    test('v1 payload (no medications key) parses without error', () {
      final json = jsonEncode({
        'version': 1,
        'meals': [],
        'food_memories': [],
      });
      final payload = ImportService.parseJson(json);
      expect(payload.version, 1);
      expect(payload.medications, isEmpty);
    });
  });

  // ─── ExportService static helpers ─────────────────────────────────────────

  group('[MFT] ExportService static helpers', () {
    final meal = MealEntry(
      id: 1,
      date: DateTime(2026, 5, 14),
      time: '7:30 AM',
      mealType: 'breakfast',
      overallSymptoms: 'mild bloating',
      rawInput: 'eggs and toast',
      createdAt: DateTime(2026, 5, 14, 7, 30),
    );

    final foodItem = FoodItem(
      id: 10,
      mealId: 1,
      name: 'Eggs',
      portion: '2 whole',
      prep: 'scrambled',
      calories: 180,
      protein: 12,
      carbs: 2,
      fat: 13,
      reaction: ReactionLevel.none,
    );

    final ingredient = Ingredient(
      foodItemId: 10,
      name: 'eggs',
      quantity: '2',
      unit: 'whole',
    );

    final reactionLog = ReactionLog(
      mealId: 1,
      checkinTime: DateTime(2026, 5, 14, 9),
      symptoms: ['Bloating'],
      severity: ReactionLevel.mild,
    );

    final medication = Medication(
      date: DateTime(2026, 5, 14),
      time: '8:00 AM',
      name: 'Metformin',
      dose: 500.0,
      unit: 'mg',
      route: 'oral',
      createdAt: DateTime(2026, 5, 14, 8),
    );

    test('mealToJson includes all required keys', () {
      final itemJson = ExportService.foodItemToJson(foodItem, [ingredient]);
      final json = ExportService.mealToJson(meal, [itemJson], [reactionLog]);

      expect(json['date'], '2026-05-14');
      expect(json['time'], '7:30 AM');
      expect(json['meal_type'], 'breakfast');
      expect(json['overall_symptoms'], 'mild bloating');
      expect(json['raw_input'], 'eggs and toast');
      expect(json.containsKey('created_at'), true);
      expect(json.containsKey('image_data'), true);
      expect(json['image_data'], isNull);
    });

    test('mealToJson embeds food_items and reaction_logs', () {
      final itemJson = ExportService.foodItemToJson(foodItem, [ingredient]);
      final json = ExportService.mealToJson(meal, [itemJson], [reactionLog]);

      final items = json['food_items'] as List;
      expect(items.length, 1);
      expect(items.first['name'], 'Eggs');

      final logs = json['reaction_logs'] as List;
      expect(logs.length, 1);
      expect(logs.first['severity'], 'mild');
      expect(logs.first['symptoms'], ['Bloating']);
    });

    test('foodItemToJson serialises reaction as enum name', () {
      final json = ExportService.foodItemToJson(foodItem, [ingredient]);
      expect(json['reaction'], 'none');
      expect(json['calories'], 180);
      expect(json['protein'], 12);
      final ings = json['ingredients'] as List;
      expect(ings.first['name'], 'eggs');
      expect(ings.first['quantity'], '2');
    });

    test('medicationToJson includes all fields', () {
      final json = ExportService.medicationToJson(medication);
      expect(json['name'], 'Metformin');
      expect(json['dose'], 500.0);
      expect(json['unit'], 'mg');
      expect(json['route'], 'oral');
      expect(json.containsKey('created_at'), true);
      expect(json.containsKey('image_data'), true);
    });
  });

  // ─── ExportService round-trip ─────────────────────────────────────────────

  group('[INV] ExportService — round-trip', () {
    test('export → parse → same meal type, food name, calories, reaction', () {
      final meal = MealEntry(
        id: 1,
        date: DateTime(2026, 5, 14),
        time: '7:30 AM',
        mealType: 'breakfast',
        rawInput: 'eggs and toast',
        createdAt: DateTime(2026, 5, 14, 7, 30),
      );
      final foodItem = FoodItem(
        id: 10,
        mealId: 1,
        name: 'Eggs',
        calories: 180,
        protein: 12,
        reaction: ReactionLevel.none,
      );
      final ingredient = Ingredient(
        foodItemId: 10,
        name: 'eggs',
        quantity: '2',
        unit: 'whole',
      );

      final itemJson = ExportService.foodItemToJson(foodItem, [ingredient]);
      final mealJson = ExportService.mealToJson(meal, [itemJson], []);

      final fullPayload = jsonEncode({
        'version': 2,
        'meals': [mealJson],
        'medications': [],
        'food_memories': [],
      });

      final parsed = ImportService.parseJson(fullPayload);
      expect(parsed.meals.first.meal.mealType, meal.mealType);
      expect(parsed.meals.first.foodItems.first.name, foodItem.name);
      expect(parsed.meals.first.foodItems.first.calories, foodItem.calories);
      expect(
        parsed.meals.first.foodItems.first.reaction,
        foodItem.reaction,
      );
      expect(parsed.meals.first.ingredientsByItem.first.first.name, 'eggs');
    });
  });

  // ─── Photo-export toggle (export_import_size AC1) ─────────────────────────

  group('[DIR] photo-export toggle', () {
    final img = Uint8List.fromList(List<int>.generate(64, (i) => i));

    final meal = MealEntry(
      id: 1,
      date: DateTime(2026, 5, 14),
      time: '7:30 AM',
      mealType: 'breakfast',
      createdAt: DateTime(2026, 5, 14, 7, 30),
      imageData: img,
    );

    final med = Medication(
      date: DateTime(2026, 5, 14),
      time: '8:00 AM',
      name: 'Metformin',
      dose: 500.0,
      createdAt: DateTime(2026, 5, 14, 8),
      imageData: img,
    );

    test('mealToJson includeImages:false drops image_data', () {
      final json = ExportService.mealToJson(meal, [], [], includeImages: false);
      expect(json['image_data'], isNull);
    });

    test('mealToJson default/true embeds base64 image_data', () {
      final json = ExportService.mealToJson(meal, [], []);
      expect(json['image_data'], base64Encode(img));
    });

    test('medicationToJson includeImages:false drops image_data', () {
      final json = ExportService.medicationToJson(med, includeImages: false);
      expect(json['image_data'], isNull);
    });

    test('medicationToJson default/true embeds base64 image_data', () {
      final json = ExportService.medicationToJson(med);
      expect(json['image_data'], base64Encode(img));
    });
  });

  // ─── Compact JSON + round-trip with photos off (AC3, AC4) ─────────────────

  group('[INV] compact export round-trips with photos off', () {
    final img = Uint8List.fromList(List<int>.generate(64, (i) => i));
    final meal = MealEntry(
      id: 1,
      date: DateTime(2026, 5, 14),
      time: '7:30 AM',
      mealType: 'breakfast',
      rawInput: 'eggs and toast',
      createdAt: DateTime(2026, 5, 14, 7, 30),
      imageData: img,
    );
    final foodItem = FoodItem(
      id: 10,
      mealId: 1,
      name: 'Eggs',
      calories: 180,
      protein: 12,
      reaction: ReactionLevel.none,
    );

    test('jsonEncode produces no pretty-print indentation', () {
      final mealJson =
          ExportService.mealToJson(meal, [], [], includeImages: false);
      final out = jsonEncode({
        'version': 3,
        'meals': [mealJson],
        'medications': [],
        'food_memories': [],
      });
      // withIndent('  ') would emit newline + leading spaces; compact has none.
      expect(out.contains('\n  '), isFalse);
      expect(out.contains('\n'), isFalse);
    });

    test('photos-off export re-parses to same fields, null image', () {
      final itemJson = ExportService.foodItemToJson(foodItem, []);
      final mealJson = ExportService.mealToJson(
        meal,
        [itemJson],
        [],
        includeImages: false,
      );
      final payload = jsonEncode({
        'version': 3,
        'meals': [mealJson],
        'medications': [],
        'food_memories': [],
      });

      final parsed = ImportService.parseJson(payload);
      final record = parsed.meals.single;
      expect(record.meal.mealType, 'breakfast');
      expect(record.meal.rawInput, 'eggs and toast');
      expect(record.foodItems.single.name, 'Eggs');
      expect(record.foodItems.single.calories, 180);
      expect(record.foodItems.single.reaction, ReactionLevel.none);
      expect(record.meal.imageData, isNull);
    });
  });

  // ─── Isolate parse parity (AC5) ───────────────────────────────────────────

  group('[INV] parseFile (isolate) == parseJson', () {
    test('parseFile returns the same payload as parseJson', () async {
      final tmp = await File(
        '${Directory.systemTemp.path}/fj_export_import_${DateTime.now().microsecondsSinceEpoch}.json',
      ).create();
      await tmp.writeAsString(_sampleJson);
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete();
      });

      final viaFile = await ImportService(StorageService()).parseFile(tmp.path);
      final viaString = ImportService.parseJson(_sampleJson);

      expect(viaFile.version, viaString.version);
      expect(viaFile.meals.length, viaString.meals.length);
      expect(viaFile.meals.first.meal.mealType,
          viaString.meals.first.meal.mealType);
      expect(viaFile.medications.length, viaString.medications.length);
      expect(viaFile.medications.first.name, viaString.medications.first.name);
      expect(viaFile.foodMemories.length, viaString.foodMemories.length);
    });
  });
}
