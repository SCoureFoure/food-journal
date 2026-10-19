import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';
import '../models/grocery.dart';
import '../models/receipt_parser.dart';
import 'ai_service.dart';

class WorkerAiService implements AiService {
  final http.Client _client;
  final String? _workerUrl;
  final String? _authToken;

  WorkerAiService({String? workerUrl, String? authToken, http.Client? client})
      : _workerUrl = workerUrl,
        _authToken = authToken,
        _client = client ?? http.Client();

  String get _resolvedUrl => _workerUrl ?? dotenv.env['MEAL_PARSER_URL'] ?? '';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  Future<http.Response> _post(Map<String, dynamic> body) async {
    final uri = Uri.parse(_resolvedUrl);
    final encoded = jsonEncode(body);
    final response = await _client.post(uri, headers: _headers, body: encoded);
    if (response.statusCode == 503) {
      return _client.post(uri, headers: _headers, body: encoded);
    }
    return response;
  }

  @override
  Future<MealParseResult> parseMeal({
    String? text,
    Uint8List? imageBytes,
    String? mealType,
    String? mealContext,
  }) async {
    if (_resolvedUrl.isEmpty) {
      return MealParseResult(
        success: false,
        errorMessage: 'MEAL_PARSER_URL not set in .env',
      );
    }

    final body = <String, dynamic>{'task': 'parse_meal'};
    if (mealType != null) body['mealType'] = mealType;

    // Prepend meal history context when available so the Worker's Gemini prompt
    // can resolve temporal references ("leftovers from last night") without
    // any changes to the Worker itself.
    final effectiveText = (mealContext != null && text != null && text.isNotEmpty)
        ? '$mealContext\n\nUser input: $text'
        : text;
    if (effectiveText != null && effectiveText.isNotEmpty) body['text'] = effectiveText;

    if (imageBytes != null) {
      body['image'] = {
        'data': base64Encode(imageBytes),
        'mimeType': 'image/jpeg',
      };
    }

    if (body.isEmpty) {
      return MealParseResult(
        success: false,
        errorMessage: 'Provide text or image to parse.',
      );
    }

    try {
      final response = await _post(body);

      if (response.statusCode != 200) {
        return MealParseResult(
          success: false,
          errorMessage: 'Worker error ${response.statusCode}: ${response.body}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final foods = (json['foods'] as List)
          .map((f) => FoodItemDraft.fromJson(f as Map<String, dynamic>))
          .toList();
      final title = json['title'] as String?;

      return MealParseResult(success: true, items: foods, title: title);
    } catch (e) {
      return MealParseResult(success: false, errorMessage: e.toString());
    }
  }

  @override
  Future<FoodDbSearchResult> searchFoodDatabase(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      return FoodDbSearchResult(success: false, errorMessage: 'Enter a search term.');
    }
    if (_resolvedUrl.isEmpty) {
      return FoodDbSearchResult(success: false, errorMessage: 'MEAL_PARSER_URL not set in .env');
    }

    try {
      final response = await _post({'task': 'food_search', 'query': q});

      if (response.statusCode != 200) {
        return FoodDbSearchResult(
          success: false,
          errorMessage: 'Worker error ${response.statusCode}: ${response.body}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final foods = (json['foods'] as List)
          .map((f) => FoodItemDraft.fromJson(f as Map<String, dynamic>))
          .toList();

      return FoodDbSearchResult(success: true, items: foods);
    } catch (e) {
      return FoodDbSearchResult(success: false, errorMessage: e.toString());
    }
  }

  @override
  Future<MedicationParseResult> parseMedication({String? text, Uint8List? imageBytes}) async {
    if (_resolvedUrl.isEmpty) {
      return MedicationParseResult(success: false, errorMessage: 'MEAL_PARSER_URL not set in .env');
    }

    final body = <String, dynamic>{'task': 'parse_medication'};
    if (text != null && text.isNotEmpty) body['text'] = text;
    if (imageBytes != null) {
      body['image'] = {'data': base64Encode(imageBytes), 'mimeType': 'image/jpeg'};
    }

    if (body.length == 1) {
      return MedicationParseResult(success: false, errorMessage: 'Provide text or image to parse.');
    }

    try {
      final response = await _post(body);

      if (response.statusCode != 200) {
        return MedicationParseResult(
          success: false,
          errorMessage: 'Worker error ${response.statusCode}: ${response.body}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return MedicationParseResult(
        success: true,
        name: json['name'] as String?,
        dose: _parseNum(json['dose']),
        unit: json['unit'] as String?,
        route: json['route'] as String?,
        notes: json['notes'] as String?,
      );
    } catch (e) {
      return MedicationParseResult(success: false, errorMessage: e.toString());
    }
  }

  @override
  Future<GroceryTidyResult> tidyGroceryList(String rawList) async {
    final raw = rawList.trim();
    if (raw.isEmpty) {
      return GroceryTidyResult(success: false, errorMessage: 'Nothing to tidy.');
    }
    if (_resolvedUrl.isEmpty) {
      return GroceryTidyResult(success: false, errorMessage: 'MEAL_PARSER_URL not set in .env');
    }

    try {
      final response = await _post({'task': 'tidy_grocery_list', 'text': raw});

      if (response.statusCode != 200) {
        return GroceryTidyResult(
          success: false,
          errorMessage: 'Worker error ${response.statusCode}: ${response.body}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final sections = (json['sections'] as List)
          .map((entry) => GrocerySection(
                name: entry['name'] as String,
                items: (entry['items'] as List).map((e) => e as String).toList(),
              ))
          .toList();

      return GroceryTidyResult(success: true, sections: sections);
    } catch (e) {
      return GroceryTidyResult(success: false, errorMessage: e.toString());
    }
  }

  @override
  Future<ReceiptParseResult> parseReceipt(String ocrText, {List<String> knownFoods = const []}) async {
    final text = ocrText.trim();
    if (text.isEmpty) {
      return ReceiptParseResult(success: false, errorMessage: 'No receipt text to read.');
    }
    if (_resolvedUrl.isEmpty) {
      return ReceiptParseResult(success: false, errorMessage: 'MEAL_PARSER_URL not set in .env');
    }

    try {
      final response = await _post({
        'task': 'parse_receipt',
        'text': buildReceiptAiText(ocrText, knownFoods),
      });

      if (response.statusCode != 200) {
        return ReceiptParseResult(
          success: false,
          errorMessage: 'Worker error ${response.statusCode}: ${response.body}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final items = <ParsedReceiptItem>[];
      for (final e in (json['items'] as List).cast<Map<String, dynamic>>()) {
        final raw = (e['raw'] as String?)?.trim() ?? '';
        if (raw.isEmpty) continue;
        final name = e['name'] as String?;
        items.add(ParsedReceiptItem(
          raw: raw,
          qty: (e['qty'] as num?)?.toDouble() ?? 1.0,
          unit: e['unit'] == 'lb' ? 'lb' : 'ea',
          food: e['food'] as bool?,
          name: (name == null || name.isEmpty) ? null : name,
        ));
      }

      return ReceiptParseResult(success: true, items: items);
    } catch (e) {
      return ReceiptParseResult(success: false, errorMessage: e.toString());
    }
  }

  static double? _parseNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
