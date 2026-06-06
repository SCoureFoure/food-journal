/// Local, deterministic canonical identity for logged food / medication names.
/// Pure — no AI, no network. Collapses trivial format variants of the same item
/// onto one key so symptom-blame and dashboards accumulate across re-entries.
/// See specs/food_entity_resolution.spec.md.
library;

/// Matches any char that is NOT a Unicode letter, digit, or whitespace.
/// Such chars are scrubbed to a space before whitespace collapsing.
final RegExp _kPunct = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);
final RegExp _kWhitespace = RegExp(r'\s+');

/// Reduce a raw item name to its canonical key:
/// lowercase → strip punctuation (→ space) → collapse whitespace runs → trim.
/// Empty / whitespace-only / punctuation-only input → `''`.
///
/// This is the single normalization used both at the storage seam (stored in
/// `canonical_name`) and by the reuse-nudge matcher, so the source of the name
/// never changes the entity math.
String canonicalize(String raw) {
  final scrubbed = raw.toLowerCase().replaceAll(_kPunct, ' ');
  return scrubbed.replaceAll(_kWhitespace, ' ').trim();
}

/// Canonical tokens of [raw] — the words of its canonical form. Empty set for
/// empty/garbage input.
Set<String> canonicalTokens(String raw) {
  final c = canonicalize(raw);
  if (c.isEmpty) return const {};
  return c.split(' ').toSet();
}

/// Two tokens count as the same entity-word above this trigram similarity.
const double _kFuzzyTokenBar = 0.4;

/// Fuzzy token-matching only kicks in once BOTH tokens are this long. Short
/// words share trigrams too easily (`ice`/`rice`, `men`/`menu`, `egg`/`eggplant`)
/// — the length gate is what keeps the fuzzy step from inventing those merges.
const int _kMinFuzzyLen = 4;

/// Unique 3-char sliding windows of [s]. For inputs shorter than 3 the whole
/// string is the lone shingle (callers length-gate before this matters).
Set<String> _trigrams(String s) {
  if (s.length < 3) return {s};
  final out = <String>{};
  for (var i = 0; i <= s.length - 3; i++) {
    out.add(s.substring(i, i + 3));
  }
  return out;
}

/// Jaccard over character trigrams — structural string similarity (this is what
/// Postgres `pg_trgm` does). Resilient to prefixes/suffixes, so `burger` scores
/// high against `hamburger` where whole-token equality scores 0.
double _trigramSim(String a, String b) {
  final ta = _trigrams(a);
  final tb = _trigrams(b);
  final union = ta.union(tb).length;
  return union == 0 ? 0 : ta.intersection(tb).length / union;
}

/// Do two canonical tokens denote the same word? Exact match, or — once both
/// clear [_kMinFuzzyLen] — a trigram overlap ≥ [_kFuzzyTokenBar]. This is the
/// single place "burger ≈ hamburger" is decided.
bool _tokensMatch(String x, String y) {
  if (x == y) return true;
  if (x.length < _kMinFuzzyLen || y.length < _kMinFuzzyLen) return false;
  return _trigramSim(x, y) >= _kFuzzyTokenBar;
}

/// Similarity of two names in [0, 1] = **fuzzy-token Jaccard**: token-set
/// Jaccard where two tokens may match by equality OR length-gated trigram
/// overlap. One coherent metric that handles both multiword phrasing (token
/// level: "turkey sandwich" vs "turkey sandwich w/ mayo") and compound words
/// (fuzzy token: "burger" vs "hamburger") — without false-merging distinct
/// dishes ("turkey sandwich" vs "tuna sandwich" stays low) or short-word
/// collisions ("ice"/"rice"). Lexical only — no semantics: "coke"/"soda" = 0.
double nameSimilarity(String a, String b) {
  final ta = canonicalTokens(a).toList();
  final tb = canonicalTokens(b).toList();
  if (ta.isEmpty || tb.isEmpty) return 0;

  // Greedy bipartite count: each typed token consumes at most one candidate
  // token, so a shared modifier can't be matched twice.
  final remaining = List<String>.from(tb);
  var matched = 0;
  for (final x in ta) {
    final idx = remaining.indexWhere((y) => _tokensMatch(x, y));
    if (idx >= 0) {
      matched++;
      remaining.removeAt(idx);
    }
  }
  final union = ta.length + tb.length - matched;
  return union == 0 ? 0 : matched / union;
}

/// Default token-overlap threshold for surfacing a reuse nudge. Tunable.
const double kNudgeThreshold = 0.5;

/// A history candidate matched against a freshly-entered name.
class NameMatch {
  /// The history item's display name (raw, for showing in the chip).
  final String candidate;

  /// Token-overlap similarity in [0, 1] against the entered name.
  final double score;

  const NameMatch({required this.candidate, required this.score});
}

/// Best reuse candidate for [typed] among [candidates], or `null` when none
/// reaches [threshold].
///
/// - [candidates] are ordered **most-recent first** by the caller; that order
///   is the tie-break for equal scores (first-seen wins).
/// - A candidate whose canonical form equals [typed]'s is skipped — it is
///   already the same entity, so there is nothing to steer.
/// - Empty / punctuation-only [typed] yields `null`.
NameMatch? bestNameMatch(
  String typed,
  Iterable<String> candidates, {
  double threshold = kNudgeThreshold,
}) {
  final typedCanon = canonicalize(typed);
  if (typedCanon.isEmpty) return null;

  NameMatch? best;
  for (final cand in candidates) {
    final candCanon = canonicalize(cand);
    if (candCanon.isEmpty || candCanon == typedCanon) continue;
    final score = nameSimilarity(typed, cand);
    // Strictly-greater keeps the earliest (most-recent) candidate on ties.
    if (score >= threshold && (best == null || score > best.score)) {
      best = NameMatch(candidate: cand, score: score);
    }
  }
  return best;
}
