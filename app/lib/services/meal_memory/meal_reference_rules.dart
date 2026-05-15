// Dart port of docs/meal_memory_starter/meal_reference_rules.py
//
// Domain rules for the pattern engine. All RegExp objects are compiled here
// (at class/const construction time) — not inside isReferential() calls.
// Add or tune rules here without touching reference_engine.dart.

import 'reference_engine.dart';

// ─── Temporal rules ───────────────────────────────────────────────────────────

final _temporalRules = <ReferenceRule>[
  ReferenceRule(
    key: 'two_days_ago',
    label: 'Two days ago reference',
    patterns: [
      RegExp(r'\bday before (?:last|yesterday)\b', caseSensitive: false),
      RegExp(r'\bnight before last\b', caseSensitive: false),
    ],
  ),
  ReferenceRule(
    key: 'yesterday',
    label: 'Yesterday reference',
    patterns: [
      RegExp(r'\byesterday\b', caseSensitive: false),
      RegExp(r'\blast night\b', caseSensitive: false),
      RegExp(r'\bthe (?:night|day) before\b', caseSensitive: false),
      RegExp(r'\bthe other night\b', caseSensitive: false),
    ],
  ),
  ReferenceRule(
    key: 'this_morning',
    label: 'This morning / earlier today',
    patterns: [
      RegExp(r'\bthis morning\b', caseSensitive: false),
      RegExp(r'\bearlier today\b', caseSensitive: false),
      RegExp(r'\bearlier\b', caseSensitive: false),
      RegExp(r'\ba few hours ago\b', caseSensitive: false),
    ],
  ),
  ReferenceRule(
    key: 'leftovers',
    label: 'Leftover reference',
    patterns: [
      RegExp(r'\bleftovers?\b', caseSensitive: false),
      RegExp(r'\bthe rest of\b', caseSensitive: false),
      RegExp(r"\bwhat(?:'s| was) left\b", caseSensitive: false),
    ],
  ),
  ReferenceRule(
    key: 'same_as_before',
    label: 'Same as a prior entry',
    patterns: [
      RegExp(r'\bsame [^.]{0,30}as\b', caseSensitive: false),
      RegExp(r'\bsame (?:thing|old|one)\b', caseSensitive: false),
      RegExp(r'\bagain\b', caseSensitive: false),
      RegExp(r'\brepeat\b', caseSensitive: false),
      RegExp(r'\b(?:the |my |as )?usual\b', caseSensitive: false),
      RegExp(r'\bmy go.?to\b', caseSensitive: false),
      RegExp(r'\bwhat i (?:always|usually|normally) (?:have|eat|get)\b', caseSensitive: false),
      RegExp(r'\bthe (?:thing|one) i (?:had|ate|got)\b', caseSensitive: false),
      RegExp(r'\blike (?:what |what I |I )?had\b', caseSensitive: false),
      RegExp(r'\bwhat i (?:had|ate)\b', caseSensitive: false),
    ],
  ),
  ReferenceRule(
    key: 'days_ago',
    label: 'N days ago',
    patterns: [
      RegExp(r'\b(?:a )?(?:few|couple(?:\s+of)?) (?:days|nights) ago\b', caseSensitive: false),
      RegExp(r'\b(?:a )?(?:few|couple(?:\s+of)?) days back\b', caseSensitive: false),
      RegExp(r'\b(?:two|three|four|five|2|3|4|5) (?:days|nights) ago\b', caseSensitive: false),
      RegExp(r'\bearlier (?:this|in the) week\b', caseSensitive: false),
      RegExp(r'\ba while (?:back|ago)\b', caseSensitive: false),
      RegExp(r'\blast week\b', caseSensitive: false),
    ],
  ),
  ReferenceRule(
    key: 'named_day',
    label: 'Named weekday reference',
    patterns: [
      RegExp(
        r'\b(?:on\s+)?(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
        caseSensitive: false,
      ),
      RegExp(r'\bthe other day\b', caseSensitive: false),
    ],
  ),
];

// ─── Meal type rules ──────────────────────────────────────────────────────────

final _mealTypeRules = <ReferenceRule>[
  ReferenceRule(
    key: 'meal_breakfast',
    label: 'Breakfast slot',
    patterns: [
      RegExp(r'\bbreakfast\b', caseSensitive: false),
      RegExp(r'\bmorning meal\b', caseSensitive: false),
      RegExp(r'\bbrunch\b', caseSensitive: false),
    ],
  ),
  ReferenceRule(
    key: 'meal_lunch',
    label: 'Lunch slot',
    patterns: [
      RegExp(r'\blunch\b', caseSensitive: false),
      RegExp(r'\bmidday\b', caseSensitive: false),
      RegExp(r'\bnoon\b', caseSensitive: false),
    ],
  ),
  ReferenceRule(
    key: 'meal_dinner',
    label: 'Dinner slot',
    patterns: [
      RegExp(r'\bdinner\b', caseSensitive: false),
      RegExp(r'\bsupper\b', caseSensitive: false),
      RegExp(r'\bevening meal\b', caseSensitive: false),
    ],
  ),
  ReferenceRule(
    key: 'meal_snack',
    label: 'Snack',
    patterns: [
      RegExp(r'\bsnack\b', caseSensitive: false),
      RegExp(r'\ba bite\b', caseSensitive: false),
      RegExp(r'\ba little something\b', caseSensitive: false),
    ],
  ),
];

// ─── Combined rule set + key sets ─────────────────────────────────────────────

final mealRules = [..._temporalRules, ..._mealTypeRules];

final temporalKeys = <String>{for (final r in _temporalRules) r.key};
final mealTypeKeys = <String>{for (final r in _mealTypeRules) r.key};

// ─── Query spec ───────────────────────────────────────────────────────────────

class MealQuerySpec {
  final int? dateOffset; // 0 = today, 1 = yesterday, 3 = ~3 days ago, null = unknown
  final String? mealType; // "breakfast" | "lunch" | "dinner" | "snack" | null
  final bool isLeftover;
  final bool matchRecent; // true → just get the N most recent entries

  const MealQuerySpec({
    this.dateOffset,
    this.mealType,
    this.isLeftover = false,
    this.matchRecent = false,
  });
}

MealQuerySpec buildQuerySpec(ReferenceProfile profile, {DateTime? now}) {
  final fired = profile.firedKeys.toSet();
  final effectiveNow = now ?? DateTime.now();

  int? dateOffset;
  if (fired.contains('two_days_ago')) {
    // "day before yesterday" fires both two_days_ago and yesterday — two_days_ago wins
    dateOffset = 2;
  } else if (fired.contains('yesterday') || fired.contains('leftovers')) {
    dateOffset = 1;
  } else if (fired.contains('days_ago')) {
    // days_ago before this_morning: "earlier this week" fires both, days_ago wins
    dateOffset = 3;
  } else if (fired.contains('this_morning')) {
    dateOffset = 0;
  }

  // named_day overrides dateOffset — "leftovers from last friday" means friday,
  // not yesterday. Walk backwards from yesterday to find the closest matching day.
  if (fired.contains('named_day')) {
    final resolved = _resolveNamedDayOffset(profile.inputText, effectiveNow);
    if (resolved != null) dateOffset = resolved;
  }

  final matchRecent = dateOffset == null &&
      (fired.contains('same_as_before') || fired.contains('named_day'));

  String? mealType;
  for (final pair in [
    ('meal_breakfast', 'breakfast'),
    ('meal_lunch', 'lunch'),
    ('meal_dinner', 'dinner'),
    ('meal_snack', 'snack'),
  ]) {
    if (fired.contains(pair.$1)) {
      mealType = pair.$2;
      break;
    }
  }

  return MealQuerySpec(
    dateOffset: dateOffset,
    mealType: mealType,
    isLeftover: fired.contains('leftovers') || fired.contains('same_as_before'),
    matchRecent: matchRecent,
  );
}

// Walk backwards from yesterday, find the most recent occurrence of the named
// weekday. Returns days ago (1–14 max). No modular math — just proximity.
int? _resolveNamedDayOffset(String normalizedInput, DateTime now) {
  const days = [
    ('monday', DateTime.monday),
    ('tuesday', DateTime.tuesday),
    ('wednesday', DateTime.wednesday),
    ('thursday', DateTime.thursday),
    ('friday', DateTime.friday),
    ('saturday', DateTime.saturday),
    ('sunday', DateTime.sunday),
  ];

  int? targetWeekday;
  for (final (name, weekday) in days) {
    if (normalizedInput.contains(name)) {
      targetWeekday = weekday;
      break;
    }
  }
  if (targetWeekday == null) return null;

  for (var i = 1; i <= 14; i++) {
    final candidate = now.subtract(Duration(days: i));
    if (candidate.weekday == targetWeekday) return i;
  }
  return null;
}
