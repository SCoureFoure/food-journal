// Dart port of docs/meal_memory_starter/pattern_engine.py
//
// Deterministic pattern detection: compile rules once, run against any input,
// return a ReferenceProfile with confidence scores and convenience flags.
//
// Confidence scoring (identical to Python source):
//   first match for a rule = 1.0; each additional match on same rule = +0.5

class ReferenceRule {
  final String key;
  final String label;
  final List<RegExp> patterns;

  const ReferenceRule({
    required this.key,
    required this.label,
    required this.patterns,
  });
}

class ReferenceProfile {
  final String inputText;
  final List<String> firedKeys;
  final Map<String, double> confidence;
  final Map<String, List<String>> evidence;
  final bool hasTemporalRef;
  final bool hasMealType;
  final double totalConfidence;

  const ReferenceProfile({
    required this.inputText,
    required this.firedKeys,
    required this.confidence,
    required this.evidence,
    required this.hasTemporalRef,
    required this.hasMealType,
    required this.totalConfidence,
  });
}

ReferenceProfile detectReferences(
  String text,
  List<ReferenceRule> rules, {
  Set<String>? temporalKeys,
  Set<String>? mealTypeKeys,
}) {
  final normalized = text.trim().toLowerCase();
  final scores = <String, double>{};
  final evidence = <String, List<String>>{};

  for (final rule in rules) {
    double ruleScore = 0.0;
    final snippets = <String>[];

    for (final pattern in rule.patterns) {
      final matchCount = pattern.allMatches(normalized).length;
      if (matchCount > 0) {
        ruleScore += 1.0 + 0.5 * (matchCount - 1);
        snippets.add(pattern.pattern);
      }
    }

    if (ruleScore > 0) {
      scores[rule.key] = ruleScore;
      evidence[rule.key] = snippets.take(3).toList();
    }
  }

  final firedKeys = scores.keys.toList()
    ..sort((a, b) {
      final cmp = scores[b]!.compareTo(scores[a]!);
      return cmp != 0 ? cmp : a.compareTo(b);
    });

  final totalConfidence = scores.values.fold(0.0, (sum, v) => sum + v);
  final firedSet = firedKeys.toSet();

  return ReferenceProfile(
    inputText: normalized,
    firedKeys: firedKeys,
    confidence: scores,
    evidence: evidence,
    hasTemporalRef: temporalKeys != null && firedSet.any(temporalKeys.contains),
    hasMealType: mealTypeKeys != null && firedSet.any(mealTypeKeys.contains),
    totalConfidence: totalConfidence,
  );
}

// Session cache keyed by normalized input string.
// Cleared automatically between app sessions (in-process only).
final _profileCache = <String, ReferenceProfile>{};

ReferenceProfile detectReferencesCached(
  String text,
  List<ReferenceRule> rules, {
  Set<String>? temporalKeys,
  Set<String>? mealTypeKeys,
}) {
  final key = text.trim().toLowerCase();
  return _profileCache.putIfAbsent(
    key,
    () => detectReferences(
      text,
      rules,
      temporalKeys: temporalKeys,
      mealTypeKeys: mealTypeKeys,
    ),
  );
}

void clearReferenceCache() => _profileCache.clear();
