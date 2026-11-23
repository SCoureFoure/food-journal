/// Pure logic for the pet's gentle "log something" reminders.
///
/// `dueNudges` decides which nudges (if any) are warranted right now, from journal
/// data plus small bookkeeping. It never schedules or fires — the notification
/// service does that from this result. Keeping it pure makes every rule unit-testable
/// without the plugin. See specs/pet_nudges.spec.md.
library;

enum PetNudgeKind { hungry, thirsty }

/// Everything `dueNudges` needs, gathered by the caller from existing data.
class PetNudgeState {
  /// `created_at` of the most recent meal, or null if none has ever been logged.
  final DateTime? lastMealLog;

  /// Today's logged water, in ml.
  final int waterToday;

  /// Today's effective water target, in ml (64 oz default applied by the caller).
  final int waterGoal;

  /// Local times nudges already fired today.
  final List<DateTime> firedToday;

  /// Manual "Pause pet reminders" switch.
  final bool paused;

  /// Master pet switch (`pet_enabled`); false means the pet is hidden entirely.
  final bool petEnabled;

  const PetNudgeState({
    this.lastMealLog,
    required this.waterToday,
    required this.waterGoal,
    this.firedToday = const [],
    this.paused = false,
    this.petEnabled = true,
  });
}

/// Gentle, pet-voiced copy for each nudge. No numbers framed as failure.
class PetNudgeCopy {
  final String title;
  final String body;
  const PetNudgeCopy(this.title, this.body);
}

const Map<PetNudgeKind, PetNudgeCopy> petNudgeCopy = {
  PetNudgeKind.hungry:
      PetNudgeCopy('Your pet is getting hungry', 'Log a meal to feed it.'),
  PetNudgeKind.thirsty:
      PetNudgeCopy('Your pet is thirsty', 'Log some water to fill its bowl.'),
};

// --- Notification id ranges (Fix A: no collisions) ---
/// Medication check-ins are offset so a meal and a medication with the same entry
/// id schedule distinct notifications.
const int medCheckinIdOffset = 1000000;
const int nudgeHungryId = 2000001;
const int nudgeThirstyId = 2000002;

// --- Tunables (see spec "Decisions") ---
const Duration kHungryAfter = Duration(hours: 5);
const Duration kMinSpacing = Duration(hours: 3);
const int kMaxNudgesPerDay = 2;
const int kQuietStartHour = 22; // 22:00..24:00 quiet
const int kQuietEndHour = 8; //   00:00..08:00 quiet
const int kThirstyAfterHour = 15;

/// True inside the no-fire window (defers to the next [kQuietEndHour]).
bool isQuietHour(DateTime now) =>
    now.hour >= kQuietStartHour || now.hour < kQuietEndHour;

/// Which nudges are warranted at [now]. Empty when gated off (disabled, paused,
/// quiet hours, daily cap reached, or too soon after the last nudge).
List<PetNudgeKind> dueNudges(PetNudgeState s, DateTime now) {
  if (!s.petEnabled || s.paused) return const [];
  if (isQuietHour(now)) return const [];
  if (s.firedToday.length >= kMaxNudgesPerDay) return const [];
  for (final t in s.firedToday) {
    if (now.difference(t) < kMinSpacing) return const [];
  }

  final out = <PetNudgeKind>[];

  final lastMeal = s.lastMealLog;
  if (lastMeal == null || now.difference(lastMeal) >= kHungryAfter) {
    out.add(PetNudgeKind.hungry);
  }

  // thirsty: after mid-afternoon and under half the target.
  if (now.hour >= kThirstyAfterHour &&
      s.waterGoal > 0 &&
      s.waterToday * 2 < s.waterGoal) {
    out.add(PetNudgeKind.thirsty);
  }

  return out;
}
