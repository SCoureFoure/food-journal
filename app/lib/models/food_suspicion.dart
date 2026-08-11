/// Symptom→item suspicion ledger. See specs/food_blame.spec.md.
///
/// A suspicion links one symptom from a check-in ([reactionLogId]) to one
/// consumed item (a food item or a medication) that may have caused it. Rows
/// accrue two ways: [SuspicionSource.auto] (every item in the lookback window
/// before the check-in) and [SuspicionSource.manual] (the user deliberately
/// blames an item). The ledger is aggregated by `(targetName, symptom)` to
/// surface patterns; flagging is downstream and out of scope here.
library;

import 'food_entity.dart' show canonicalize;
import 'food_item.dart' show ReactionLevel;

/// Auto-blame lookback: every item logged within this window before the
/// check-in time accrues a low-weight suspicion. ~one waking day / dinner→
/// breakfast overnight.
const Duration kAutoBlameWindow = Duration(hours: 16);

/// Manual-blame lookback: the blame modal lists items this far back, wider than
/// [kAutoBlameWindow] so the user can reach an item auto-blame missed.
const Duration kManualBlameWindow = Duration(hours: 24);

/// Effective weight multiplier for a deliberate (manual) blame vs. an auto one.
/// Manual blame is a stronger signal. Placeholder — tune later.
const double kManualWeightMultiplier = 3.0;

enum SuspicionSource { auto, manual }

enum SuspicionTargetType { food, medication }

class FoodSuspicion {
  final int? id;
  final int reactionLogId;
  final String symptom;
  final SuspicionTargetType targetType;
  final int targetId;
  final String targetName;
  final double baseWeight;
  final SuspicionSource source;
  final DateTime createdAt;

  const FoodSuspicion({
    this.id,
    required this.reactionLogId,
    required this.symptom,
    required this.targetType,
    required this.targetId,
    required this.targetName,
    required this.baseWeight,
    required this.source,
    required this.createdAt,
  });
}

/// A consumed item eligible to be blamed — a food item or medication with the
/// real timestamp it was logged at. Surfaces in the blame modal and feeds
/// auto-blame.
class BlameCandidate {
  final SuspicionTargetType type;
  final int targetId;
  final String name;

  /// Canonical identity for cross-log accumulation (the stored
  /// `canonical_name`). Null for legacy/ad-hoc candidates → falls back to
  /// canonicalizing [name] so the ledger key is always normalized.
  final String? canonicalName;
  final DateTime timestamp;
  final String? subtitle;

  const BlameCandidate({
    required this.type,
    required this.targetId,
    required this.name,
    this.canonicalName,
    required this.timestamp,
    this.subtitle,
  });

  /// Stable identity for selection sets / dedupe across the modal and ledger.
  String get key => '${type.name}:$targetId';

  /// The ledger grouping key — stored canonical name, or a freshly canonicalized
  /// [name] when none was supplied.
  String get canonicalKey =>
      canonicalName ?? canonicalize(name);
}

/// One reviewable episode in the blame-history dashboard — a `(check-in,
/// symptom)` pair that produced ≥1 suspicion row, with enough context for the
/// user to judge it: when it happened, how bad it was, and what it blamed
/// (auto + manual targets together — unlike the feeling tile's manual-only
/// "Blamed" section, this view's whole point is surfacing what accrued quietly).
/// See specs/blame_history.spec.md.
class BlameHistoryEntry {
  final int reactionLogId;
  final String symptom;
  final DateTime checkinTime;
  final ReactionLevel severity;
  final List<String> blamedNames; // distinct target names, insertion-ordered
  final bool dismissed;

  const BlameHistoryEntry({
    required this.reactionLogId,
    required this.symptom,
    required this.checkinTime,
    required this.severity,
    required this.blamedNames,
    required this.dismissed,
  });
}

/// Stable identity for a `(check-in, symptom)` episode — shared by the
/// dismissed-key lookup set and the dashboard's toggle anchors.
String blameHistoryKey(int reactionLogId, String symptom) =>
    '$reactionLogId:$symptom';

/// Stored target names are canonical (lowercase/trimmed) for ledger grouping;
/// prettify for display. Shared by the feeling tile's "Blamed" chips and the
/// blame-history dashboard — both surface raw `targetName`s from this ledger.
String titleCase(String s) => s
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

/// Aggregated suspicion for one `(targetName, symptom)` pair across all logs.
class SuspicionScore {
  final String targetName;
  final String symptom;
  final double score;

  const SuspicionScore({
    required this.targetName,
    required this.symptom,
    required this.score,
  });
}

// ── Pure blame logic ──────────────────────────────────────────────────────────
// Extracted so the meaningful behavior (window, weight, fan-out, aggregation) is
// unit-testable without native sqlite3. StorageService delegates to these.

/// Normalized base weight for a symptom level: mild=1, moderate=2, bad=3,
/// none/pending=0 (and below). Independent of the raw [ReactionLevel] enum index
/// (which puts pending/none at 0/1).
double suspicionWeightFor(ReactionLevel level) =>
    (level.index - ReactionLevel.none.index).toDouble();

/// Effective weight on read: base × source multiplier × decay(age). Decay is the
/// identity (1.0) for now — see specs/food_blame.spec.md (deferred).
double effectiveSuspicionWeight({
  required double baseWeight,
  required SuspicionSource source,
}) =>
    baseWeight *
    (source == SuspicionSource.manual ? kManualWeightMultiplier : 1.0);

/// Open interval `(anchor − window, anchor)`. An item exactly at the far edge
/// (anchor − window) is excluded, as is the check-in instant itself.
bool isWithinBlameWindow({
  required DateTime timestamp,
  required DateTime anchor,
  required Duration window,
}) {
  final from = anchor.subtract(window);
  return timestamp.isAfter(from) && timestamp.isBefore(anchor);
}

/// The rows a single check-in should produce: one `auto` row per in-window
/// [autoCandidates] × active symptom, plus one `manual` row per
/// [manualSelections] × active symptom. Symptoms at none/pending are skipped
/// (nothing to blame for). Pure → idempotent regenerate.
List<FoodSuspicion> buildSuspicionRows({
  required int reactionLogId,
  required Map<String, ReactionLevel> symptomLevels,
  required List<BlameCandidate> autoCandidates,
  required List<BlameCandidate> manualSelections,
  required DateTime createdAt,
}) {
  final active = symptomLevels.entries
      .where((e) =>
          e.value != ReactionLevel.none && e.value != ReactionLevel.pending)
      .toList();
  final rows = <FoodSuspicion>[];
  for (final s in active) {
    final weight = suspicionWeightFor(s.value);
    for (final c in autoCandidates) {
      rows.add(_row(reactionLogId, s.key, c, weight, SuspicionSource.auto, createdAt));
    }
    for (final c in manualSelections) {
      rows.add(_row(reactionLogId, s.key, c, weight, SuspicionSource.manual, createdAt));
    }
  }
  return rows;
}

FoodSuspicion _row(int logId, String symptom, BlameCandidate c, double weight,
        SuspicionSource source, DateTime createdAt) =>
    FoodSuspicion(
      reactionLogId: logId,
      symptom: symptom,
      targetType: c.type,
      targetId: c.targetId,
      targetName: c.canonicalKey,
      baseWeight: weight,
      source: source,
      createdAt: createdAt,
    );

/// Aggregates ledger rows by `(targetName, symptom)`, summing effective weight,
/// highest score first. Tested spec of the aggregation math — the live SQL
/// path used by the UI is `StorageService.getBlameHistory`.
List<SuspicionScore> aggregateSuspicions(List<FoodSuspicion> rows) {
  final sums = <String, double>{};
  final keyParts = <String, ({String name, String symptom})>{};
  for (final r in rows) {
    // NUL separator, written as the \u0000 escape (not a raw NUL byte) so this
    // file stays plain text — a raw NUL makes ripgrep skip it silently.
    final key = '${r.targetName}\u0000${r.symptom}';
    sums[key] = (sums[key] ?? 0) +
        effectiveSuspicionWeight(baseWeight: r.baseWeight, source: r.source);
    keyParts[key] = (name: r.targetName, symptom: r.symptom);
  }
  final scores = sums.entries
      .map((e) => SuspicionScore(
            targetName: keyParts[e.key]!.name,
            symptom: keyParts[e.key]!.symptom,
            score: e.value,
          ))
      .toList()
    ..sort((a, b) => b.score.compareTo(a.score));
  return scores;
}

/// Filters out ledger rows whose `(reactionLogId, symptom)` the user has
/// dismissed (see [BlameHistoryEntry]/`suspicion_exclusions`). [dismissedKeys]
/// holds [blameHistoryKey] strings. This is the tested spec of that filter —
/// the live SQL path used by the UI is `StorageService.getBlameHistory`.
List<FoodSuspicion> excludeDismissedSuspicions(
  List<FoodSuspicion> rows,
  Set<String> dismissedKeys,
) =>
    rows
        .where((r) =>
            !dismissedKeys.contains(blameHistoryKey(r.reactionLogId, r.symptom)))
        .toList();

/// Groups raw ledger rows into reviewable `(check-in, symptom)` episodes — one
/// entry per distinct pair, carrying every distinct target name it blamed
/// (auto + manual, insertion-ordered/deduped), newest-`checkinTime` first (ties
/// by `reactionLogId` desc — `reaction_logs` carries no separate `created_at`).
/// Pure → testable without native sqlite3; `StorageService.getBlameHistory`
/// supplies [checkinTimes] / [symptomLevelsByLog] (from `reaction_logs`) and
/// [dismissedKeys] (from `suspicion_exclusions`, as [blameHistoryKey] strings).
/// Logs missing from [checkinTimes] (e.g. deleted between reads) are skipped
/// defensively.
List<BlameHistoryEntry> buildBlameHistory({
  required List<FoodSuspicion> rows,
  required Map<int, DateTime> checkinTimes,
  required Map<int, Map<String, ReactionLevel>> symptomLevelsByLog,
  required Set<String> dismissedKeys,
}) {
  final order = <String>[];
  final names = <String, List<String>>{};
  final seenNames = <String, Set<String>>{};
  final keyParts = <String, (int, String)>{};
  for (final r in rows) {
    final key = blameHistoryKey(r.reactionLogId, r.symptom);
    if (!names.containsKey(key)) {
      order.add(key);
      names[key] = [];
      seenNames[key] = {};
      keyParts[key] = (r.reactionLogId, r.symptom);
    }
    if (seenNames[key]!.add(r.targetName)) names[key]!.add(r.targetName);
  }

  final entries = <BlameHistoryEntry>[];
  for (final key in order) {
    final (logId, symptom) = keyParts[key]!;
    final checkinTime = checkinTimes[logId];
    if (checkinTime == null) continue; // log vanished between reads — skip
    final severity = symptomLevelsByLog[logId]?[symptom] ?? ReactionLevel.pending;
    entries.add(BlameHistoryEntry(
      reactionLogId: logId,
      symptom: symptom,
      checkinTime: checkinTime,
      severity: severity,
      blamedNames: names[key]!,
      dismissed: dismissedKeys.contains(key),
    ));
  }
  entries.sort((a, b) {
    final byTime = b.checkinTime.compareTo(a.checkinTime);
    return byTime != 0 ? byTime : b.reactionLogId.compareTo(a.reactionLogId);
  });
  return entries;
}
