# Spec — Blame suspects (ranked likely triggers per symptom)

> Status: active · Feature: blame_suspects · Added: 2026-10-20
> Builds on [food_blame](food_blame.spec.md) (the ledger) and
> [blame_history](blame_history.spec.md) (dismissing episodes).

## Requirement
The blame ledger accrues suspicion but never tells the user anything. Add a
**Suspects** tab to the Blame History screen that lists, for each symptom, the
foods and medications most likely behind it, ranked by how often they line up
with that symptom relative to how often they are eaten. A food appears only once
it has been blamed in enough separate check-ins to be more than noise. Read-only:
the user corrects the data by dismissing episodes on the Episodes tab, and the
Suspects tab reflects that immediately.

## Out of scope (future work)
- User flag ("I know this triggers me") and system flag (`food_memories.flagged`
  set when a threshold is crossed) — their own specs.
- Decay of old blame (seam stays the identity, see food_blame).
- Per-symptom windows.
- Tapping a suspect to drill into its episodes.

## Constraints (inherited)
- Ledger rows are keyed by canonical `targetName`; food and medication rows with
  the same canonical name aggregate together (same as `aggregateSuspicions`).
- Dismissed episodes (`suspicion_exclusions`, keyed by `blameHistoryKey`) are
  excluded from every aggregation (blame_history).
- Effective weight = `effectiveSuspicionWeight` (severity weight × manual
  multiplier × decay 1.0).
- No schema change. Schema stays v16.

## Decisions (pinned 2026-10-20)
1. **Placement** — a second tab on the Blame History screen: `Episodes` (the
   existing list, default) and `Suspects`. *(user)*
2. **Ranking** — by **rate** = score ÷ times eaten, highest first. Score is the
   summed effective weight of the item's non-dismissed rows for that symptom. *(user)*
3. **Threshold** — an item is listed for a symptom only when it was blamed in
   **≥ 3 distinct non-dismissed check-ins** (`kSuspectMinEpisodes = 3`) for that
   symptom. Episodes count distinct `reactionLogId`s, not rows. *(user)*
4. **Times eaten** — the count of all `food_items` rows plus all `medications`
   rows in history whose canonical name (stored `canonicalName`, else
   `canonicalize(name)`) equals the target name. Whole history, not windowed.
5. **Zero denominator** — an item with no matching rows (deleted since) uses a
   denominator of 1, so `rate = score`.
6. **Order** — symptom sections ascending by symptom string; within a section,
   rate desc, then episode count desc, then target name asc.
7. **Row text** — title-cased name; subtitle `Blamed in N check-ins · eaten M
   times` (`eaten 1 time` when M = 1; `eaten 0 times` when 0). Rows are not
   tappable.
8. **Loading** — the screen loads episodes and suspects together; one failure
   shows the existing error text on both tabs. Dismiss/restore reloads both.

## Acceptance criteria (Given / When / Then)

### Pure — `buildSuspects` (app/lib/models/food_suspicion.dart)
- **AC1 threshold** — Given `milk` blamed for Bloating in logs 1, 2, 3 and
  `bread` in logs 1, 2, when built, then `milk` is listed and `bread` is not.
- **AC2 episodes are distinct check-ins** — Given `milk` has two rows in log 1
  and one in log 2, then its episode count is 2 and it is not listed (counting
  rows would wrongly give 3).
- **AC3 dismissed excluded** — Given `milk` in logs 1–4 for Bloating with
  `4:Bloating` dismissed, then `milk` has 3 episodes and score 3.0. A dismissal
  on another symptom (`4:Nausea`) changes nothing for Bloating.
- **AC4 ranked by rate, not score** — Given Bloating: `milk` score 3 eaten 10
  (rate 0.3), `cheese` score 5 eaten 5 (rate 1.0), `coffee` score 6 eaten 30
  (rate 0.2), then order is cheese, milk, coffee.
- **AC5 missing denominator** — Given `pill` with score 3 and no times-eaten
  entry, then `timesEaten` = 0 and `rate` = 3.0.
- **AC6 order** — symptoms ascending; ties on rate break by episodes desc, then
  name asc.
- **AC7 empty** — no rows gives an empty list.
- **AC8 food and medication merge** — rows for `iron` as food and as medication
  form one entry.

### Storage — `StorageService.getSuspects`
- **AC9** — returns `buildSuspects` over every ledger row, every exclusion, and
  times-eaten counts per decision 4. No ledger rows gives an empty list.
  (SQL path verified on device, like the other ledger reads.)

### Screen — Blame History tabs
- **AC10** — the screen shows tabs `Episodes` and `Suspects`; `Episodes` is
  selected first and behaves exactly as before.
- **AC11** — the Suspects tab shows one section per symptom with its suspects in
  the order given, each with name and subtitle per decision 7.
- **AC12** — with no suspects, the Suspects tab shows an empty state naming the
  3-check-in threshold.
- **AC13** — dismissing an episode on the Episodes tab reloads suspects.

## Anchors (explore rig)
| Id | Widget |
| --- | --- |
| `tab-blame-episodes` | Episodes tab |
| `tab-blame-suspects` | Suspects tab |
| `blame-suspects-section-<symptom-slug>` | Symptom section header |
| `blame-suspect-item-<symptom-slug>-<name-slug>` | Suspect row |
| `blame-suspects-empty-state` | Empty state |

Slugs: lowercase, spaces → dashes (same rule as `blame-history-item-…`).

## Verifies-with
- `app/test/models/blame_suspects_test.dart` — AC1–AC8.
- `app/test/screens/blame_history_screen_test.dart` — AC10–AC13.
- AC9 — `flutter analyze` here; SQL path on device.
