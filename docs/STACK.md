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
| `drift` | SQLite ORM, type-safe queries | Schema v4; migrations in `app_database.dart` |
| `drift_flutter` | drift Flutter integration | |
| `flutter_local_notifications` | Post-entry check-in reminders | Pinned `^18.0.1`; v21+ requires Dart ≥3.10 |
| `flutter_timezone` | Timezone for scheduled notifs | v5 returns `TimezoneInfo`; use `.identifier` |
| `image_picker` | Camera + gallery access | |
| `http` | Cloudflare Worker + Claude API calls | Not dio |
| `flutter_dotenv` | API keys + config from `.env` | |
| `share_plus` | OS share sheet for export | |
| `shared_preferences` | AI toggle persistence | |
| `intl` | Date/time formatting | |
| `path_provider` | App documents directory | |

---

## AI Integration

Two implementations behind a common `AiService` abstract class.

### Primary — Cloudflare Worker (`WorkerAiService`)

The app posts JSON to a Cloudflare Worker which calls Gemini server-side. The Gemini key never leaves the Worker — only the endpoint URL is in the app.

`app/.env` (bundled into APK — no secrets here):

```env
MEAL_PARSER_URL=https://your-worker.workers.dev
CHECKIN_DELAY_MINUTES=90
```

```dart
class WorkerAiService implements AiService {
  String get _resolvedUrl => dotenv.env['MEAL_PARSER_URL'] ?? '';

  Future<MealParseResult> parseMeal({String? text, Uint8List? imageBytes, ...}) async {
    final body = {'task': 'parse_meal', if (text != null) 'text': text, ...};
    final response = await _client.post(Uri.parse(_resolvedUrl), body: jsonEncode(body));
    // auto-retry once on 503
    ...
  }
}
```

### Fallback — Claude direct (`AiService.fromEnv()`)

Used only when `MEAL_PARSER_URL` is unset. `ANTHROPIC_API_KEY` is read from
`Platform.environment` or the **repo-root `.env`** — never from `app/.env`.
Putting `ANTHROPIC_API_KEY` in `app/.env` would bundle it into the compiled app binary.

`.env` (repo root, gitignored, developer machine only):

```env
ANTHROPIC_API_KEY=sk-ant-...
```

---

## Local Storage — drift

`driftDatabase(name: 'food_journal')` → the DB lives in the app **documents**
directory (`getApplicationDocumentsDirectory()`), **not** the Android `databases/`
dir. Schema version + `MigrationStrategy` are in `app_database.dart`.

**On-device location (debug builds, emulator + real device):**

```text
/data/data/com.foodjournal.app/app_flutter/food_journal.sqlite      (+ -wal, -shm)
```

There is **no `sqlite3` binary on the device** — query it on the host. Pull via
`run-as` (works on debuggable builds without root):

```powershell
# main DB file is committed schema+data; WAL may hold uncommitted pages
adb -s emulator-5554 exec-out run-as com.foodjournal.app `
    cat app_flutter/food_journal.sqlite > pulled.sqlite
# then inspect locally, e.g. python -c "import sqlite3; ..."  or sqlite3 pulled.sqlite
#   PRAGMA user_version;   -> current schema version
#   PRAGMA table_info(food_items);
```

`PRAGMA user_version` is the live schema version on disk (drift's
`schemaVersion`). Migrations run on first open after an upgrade — to verify one
actually applied, launch the app once on a populated DB, then pull and check
`user_version` + the new columns/backfill.

---

## Notifications — flutter_local_notifications

Uses `zonedSchedule` (requires `flutter_timezone`). Android 13+ requires runtime notification permission — prompted on first entry save.

Pinned at `^18.0.1`; v21+ requires Dart ≥3.10 which this project does not meet.

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
