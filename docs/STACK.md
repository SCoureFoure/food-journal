# Food Journal — Tech Stack

## Framework

**Flutter** (Dart)

- Android primary target; iOS with same codebase
- Local-only — no backend required

---

## Confirmed Patterns (from existing Flutter repo)

These patterns are in active use and must be matched for consistency.

### State Management — StatefulWidget + setState

No Riverpod, no Bloc. `Provider` is declared in the existing repo but unused. Match the live pattern:

```dart
class _LogMealScreenState extends State<LogMealScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  List<FoodItemDraft> _parsedItems = [];

  void _submit() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    final result = await _aiService.parseMeal(text: _textController.text);
    setState(() {
      _isLoading = false;
      if (result.success) _parsedItems = result.items!;
      else _errorMessage = result.errorMessage;
    });
  }
}
```

### Typed Result Wrappers

All service calls return a typed result object. No raw exceptions surfacing to UI:

```dart
class MealParseResult {
  final bool success;
  final List<FoodItemDraft>? items;
  final String? errorMessage;
  MealParseResult({required this.success, this.items, this.errorMessage});
}
```

### Service Injection — Direct Instantiation

Each screen creates its own service. Services create their own dependencies internally:

```dart
class _HomeScreenState extends State<HomeScreen> {
  final _storageService = StorageService();
  final _aiService = AiService();
```

No GetIt, no locator pattern.

### Async UI Pattern

```text
_isLoading → CircularProgressIndicator
_errorMessage != null → ErrorView + retry button
else → content
```

Parallel loads use `Future.wait([...])`.

### Folder Structure — Layer-first

```text
lib/
├── main.dart
├── models/         # plain Dart classes + fromJson/toJson
├── services/       # business logic, API calls, DB access
├── screens/        # StatefulWidgets, sub-folders by feature
│   ├── home/
│   ├── log_meal/
│   ├── meal_detail/
│   ├── checkin/
│   └── export/
└── widgets/        # reusable UI components
```

---

## Key Packages

| Package | Purpose | Notes |
| ------- | ------- | ----- |
| `drift` | SQLite ORM, type-safe queries | Adding fresh — no existing pattern |
| `drift_flutter` | drift Flutter integration | Replaces sqlite3_flutter_libs |
| `flutter_local_notifications` | Post-meal check-in | Adding fresh — no existing pattern |
| `flutter_timezone` | Timezone for scheduled notifs | Required by flutter_local_notifications |
| `image_picker` | Camera + gallery access | |
| `http` | Claude API HTTP calls | Match existing repo (not dio) |
| `flutter_dotenv` | API key from `.env` | |
| `share_plus` | OS share sheet for CSV/grocery export | |
| `intl` | Date/time formatting | |
| `path_provider` | App documents directory | |

---

## AI Integration

**Anthropic Claude API** — `claude-sonnet-4-6`

REST API via `http` package. No official Flutter SDK.

```dart
class AiService {
  final _client = http.Client();
  final _apiKey = dotenv.env['ANTHROPIC_API_KEY']!;

  Future<MealParseResult> parseMeal({String? text, Uint8List? imageBytes}) async {
    try {
      final content = <Map<String, dynamic>>[];
      if (imageBytes != null) {
        content.add({
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': 'image/jpeg',
            'data': base64Encode(imageBytes),
          }
        });
      }
      if (text != null) content.add({'type': 'text', 'text': text});

      final response = await _client.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': 'claude-sonnet-4-6',
          'max_tokens': 1024,
          'system': _systemPrompt,
          'messages': [{'role': 'user', 'content': content}],
        }),
      );

      if (response.statusCode != 200) {
        return MealParseResult(success: false, errorMessage: 'API error ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final json = jsonDecode(data['content'][0]['text'] as String);
      return MealParseResult(success: true, items: _parseItems(json));
    } catch (e) {
      return MealParseResult(success: false, errorMessage: e.toString());
    }
  }
}
```

API key in `.env` (gitignored):

```
ANTHROPIC_API_KEY=sk-ant-...
CHECKIN_DELAY_MINUTES=90
```

---

## Local Storage — drift

Adding fresh. No existing pattern in reference repo to follow.

Database file lives in app documents directory via `path_provider`.

---

## Notifications — flutter_local_notifications

Adding fresh. Adding `flutter_timezone` alongside for `zonedSchedule` support.

Android 13+ requires runtime notification permission request.

---

## Environment Setup

```bash
flutter create food_journal --platforms android,ios
cd food_journal

# Core
flutter pub add drift drift_flutter
flutter pub add flutter_local_notifications flutter_timezone
flutter pub add image_picker
flutter pub add http
flutter pub add flutter_dotenv
flutter pub add share_plus
flutter pub add intl
flutter pub add path_provider

# Dev
flutter pub add --dev drift_dev build_runner
```

---

## Android Permissions (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
```
