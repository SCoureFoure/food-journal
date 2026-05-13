import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';
import 'ai_service.dart';

class WorkerAiService implements AiService {
  final _client = http.Client();

  String get _workerUrl => dotenv.env['MEAL_PARSER_URL'] ?? '';

  @override
  Future<MealParseResult> parseMeal({String? text, Uint8List? imageBytes, String? mealType}) async {
    if (_workerUrl.isEmpty) {
      return MealParseResult(
        success: false,
        errorMessage: 'MEAL_PARSER_URL not set in .env',
      );
    }

    final body = <String, dynamic>{'task': 'parse_meal'};
    if (mealType != null) body['mealType'] = mealType;
    if (text != null && text.isNotEmpty) body['text'] = text;
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
      final response = await _client.post(
        Uri.parse(_workerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

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
}
