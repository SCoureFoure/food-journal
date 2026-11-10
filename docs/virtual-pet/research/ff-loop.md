# fitness_friends: motivation and engagement loop

Scope: how real-world activity feeds the pet, the energy and resource economy, adventures and events, and what is built versus only designed. All paths are repo-relative to `C:/Users/SCora/Documents/Repositories/`. Statements marked "Inference:" are my reading; everything else was seen in files. No git was used.

Short version (fact): the code implements a manual-entry loop. The user logs a workout, the backend converts it to "energy points", and the user then manually applies that activity to one creature. The effect depends on whether the creature is on an adventure: if so, energy becomes adventure stamina and health; if not, it becomes creature energy, XP, and stat points. Adventures are free to start and are driven by stamina, health and event resolution. There is no HealthKit or Google Fit code, no notifications, no streaks, and no punishment for absence.

## 1. Input: how fitness activity enters

**Manual log is the only working path.**
- Flutter form: `fitness_friends/flutter_app/lib/screens/fitness/log_activity_screen.dart:13-182`. Fields the user can enter: activity type (6 choices, lines 27-76), duration in minutes (253-274), distance in km (278-298), steps (controller line 17), calories (18), average heart rate (19). The code that builds the request converts minutes to seconds and km to meters (lines 117-127) and sets `endedAt = now`, `startedAt = now - duration` (121-122).
- Backend endpoint: `POST /v1/fitness/activities`, handler `fitness_friends/backend/src/controllers/fitnessController.ts:40-87`. Required: `activityType`, `duration`, `startedAt`, `endedAt` (line 44). `activityType` is validated against the Prisma enum (61). Platform is not read from the request; the service defaults it to `MANUAL` (`fitness_friends/backend/src/services/fitnessService.ts:115`).

**Activity fields** (`fitness_friends/backend/prisma/schema.prisma:77-108`): `platform`, `externalId?`, `activityType`, `steps?` (Int), `distance?` (meters), `duration?` (seconds), `calories?`, `heartRateAvg?`, `startedAt`, `endedAt`, `recordedAt`, `energyPointsAwarded` (Float, default 0), `processed` (Boolean, default false). `ActivityType` is WALKING, RUNNING, SWIMMING, CYCLING, STRENGTH, OTHER (schema.prisma:110-117).

**Health platforms: designed, not built.**
- The enum lists `HEALTHKIT`, `GOOGLEFIT`, `FITBIT`, `MANUAL` (schema.prisma:70-75) and a `FitnessConnection` model exists (56-68). A grep of `fitness_friends/backend/src` for `fitnessConnection` found no use. A grep of `backend/src/**/*.ts`, `flutter_app/lib/**/*.dart` and `pubspec.yaml` for HealthKit, GoogleFit and `current-event` found nothing. `flutter_app/pubspec.yaml` has no health or pedometer package match.
- Design: `fitness_friends/docs/design/03-fitness-integration.md:7-51` (adapter layer, normalization, dedup at 201-242, pull/push model at 55-65).
- Roadmap says "Not Started" and "nice to have": `fitness_friends/docs/design/COMPREHENSIVE_ROADMAP.md:361-375`. The assessment doc agrees: "External platform integration (HealthKit/Google Fit) not started" (`fitness_friends/docs/design/DESIGN_DOCS_ASSESSMENT.md:78`).

**Validation gaps (fact, from the author's own debt list):** no check that `endedAt > startedAt` or that the activity is not in the future (`fitness_friends/docs/process/TECHNICAL_DEBT.md:92-110`), no rate limit (TECHNICAL_DEBT.md:280-292), no edit or delete of logged activities (148-159). I did not find the proposed checks in `fitnessController.ts:40-87`. Inference: a user can type any duration and get energy for it.

## 2. Conversion: activity to energy, XP, stats, resources

The pipeline has three stages. Stage A happens at log time. Stages B and C happen when the user applies an activity to a creature.

### Stage A: activity to energy points (EP)

`fitness_friends/backend/src/services/fitnessService.ts:84-96`:

```
EP = round2( minutes * ENERGY_PER_MINUTE[type] + (distance_m / 100) * 0.01 )
```

Multipliers per minute (fitnessService.ts:45-52): RUNNING 2.0, SWIMMING 1.8, CYCLING 1.5, STRENGTH 1.3, WALKING 1.0, OTHER 0.8.

Facts about the formula:
- Distance bonus is tiny: 0.01 EP per 100 m, so 5 km adds 0.5 EP (line 93). Test confirms: 30 min run plus 5000 m = 60.5 (`fitness_friends/backend/tests/unit/services/fitnessService.test.ts:46-49`).
- Steps, calories and heart rate are stored but do not enter the formula (lines 84-96 use only type, duration, distance).
- Result is stored on the row at log time (`energyPointsAwarded`, fitnessService.ts:136) with `processed: false` (137).
- No cap on EP per activity or per day on the backend. The Flutter preview clamps to 0-100 (`fitness_friends/flutter_app/lib/services/fitness_service.dart:147`).

Examples (from tests): 30 min running = 60, 30 min walking = 30, 60 min swimming = 108, 20 min strength = 26 (fitnessService.test.ts:31-59).

### Stage B: applying an activity to a creature

`POST /v1/fitness/activities/:id/apply` with `{creatureId}`: `fitness_friends/backend/src/controllers/fitnessController.ts:160-333`. It checks ownership of both, rejects an already-processed activity (235-248), calls `applyEnergyToCreature(creatureId, energyPointsAwarded, activityType)` (295-299), then `markActivityProcessed` (302). Each activity can be applied once and to one creature. There is no transaction around those two steps (known debt, TECHNICAL_DEBT.md:9-69 and 175-187; the TODO is at fitnessController.ts:283-289).

`applyEnergyToCreature`: `fitness_friends/backend/src/services/creatureService.ts:339-434`. Creature must be ACTIVE (352-354). Then it branches.

**Branch 1: creature has an ACTIVE adventure** (creatureService.ts:357-378). Calls `restoreAdventureResources` and nothing else. The creature's own energy, XP and stats are not touched (this branch returns at 374-377).
- `adventure.currentStamina += floor(EP / 2)`, capped at `maxStaminaPool` (`fitness_friends/backend/src/services/adventureService.ts:401,405`).
- `adventure.currentHealth += floor(EP / 4)`, capped at 100 (adventureService.ts:402,406).
- Example: 60 EP gives +30 stamina and +15 health.

**Branch 2: no active adventure** (creatureService.ts:380-433):
- `creature.energy += floor(EP)`, capped at 100 (line 398).
- `creature.experiencePoints += floor(EP)` (line 399).
- Stat points: `statBoost = floor(EP / 10)` (382), split evenly with `floor(statBoost / numberOfStats)` per stat (405), each stat capped at 1200 (409-417). Which stats: `ACTIVITY_STAT_BOOST` (fitnessService.ts:65-72): RUNNING and CYCLING speed+stamina, SWIMMING stamina+power, WALKING stamina+intelligence, STRENGTH power+flying, OTHER intelligence.
- Mood is set to `HAPPY` only if `statBoost > 0` and the activity maps to stats (line 403, 422).
- Worked case: 60 EP running with no adventure. energy +60 (cap 100), XP +60, statBoost = 6, per stat floor(6/2) = 3, so speed +3 and stamina +3, mood HAPPY. A 5 EP activity gives statBoost 0, so energy +5 and XP +5 only. A 10-19 EP OTHER activity gives statBoost 1 over one stat, so +1 intelligence. A 10-19 EP running activity gives statBoost 1, boostPerStat floor(1/2) = 0, so no stat gain, but mood still becomes HAPPY (line 403 tests `statBoost > 0`, not boostPerStat). Inference: odd-numbered boosts lose a point to rounding.

**XP to level.** Applying activities adds XP but does not recompute `level` anywhere in `applyEnergyToCreature` (no `level` field in `updateData`, creatureService.ts:388-400). Level changes only in `completeAdventure` (adventureService.ts:677-678: `level = floor(XP / 100) + 1`), and at that point it uses total XP, so XP from fitness counts toward the next level-up on the next completed adventure. Inference: a user who only works out will not see their level change until they complete an adventure. Event XP (skill, rest, discovery) also does not update `level` (adventureService.ts:1014-1019, 1076-1081, 1235-1240, 1313-1318).

**Energy has no sink in the current code.** `creature.energy` is stored and increased (schema.prisma:164) but nothing reads it as a requirement. `startAdventure` sets `energyCost: 0` (adventureService.ts:163) and never reads `creature.energy` (lines 112-195). Inference: creature energy is a vestigial number.

## 3. Spend: what energy and resources are spent on

| Resource | Where it lives | Spent on | Cite |
|---|---|---|---|
| Creature `energy` (0-100) | `Creature.energy` | Nothing in current code. Designed to pay adventure entry (10-50). | schema.prisma:164; adventureService.ts:89-93 ("energy cost calculation removed"); docs `fitness_friends/docs/design/ENERGY_SYSTEM_SUMMARY.md:63-89` |
| Adventure stamina pool | `Adventure.currentStamina`, max `maxStaminaPool` | Skill challenge attempts, training, | adventureService.ts:987-993, 456-470 |
| Adventure health | `Adventure.currentHealth` (0-100, starts 100) | Lost on failed checks; spent for "guaranteed" success; reaching 0 abandons | adventureService.ts:996-1010, 1127-1158 |
| Skill-challenge "inspiration" tokens | not in schema | Reroll failed checks | Designed only: `fitness_friends/docs/design/10-adventure-event-system.md:735-783`; grep of `backend/src` found 0 matches for inspiration or reroll |

**Stamina pool size.** `min(100, 10 + floor(staminaStat / 5))` (adventureService.ts:105-107). Fact: this differs from the docs, which say `min(100, floor(stamina / 10))` (`fitness_friends/docs/design/RESOURCE_SYSTEM_CHANGES.md:67,187`; README.md:474; COMPREHENSIVE_ROADMAP.md:489). With stamina 30 the code gives 16; the docs' formula gives 3.

**Costs per action:**
- Skill challenge attempt: `staminaCost.standard` or `.highRisk` from the event template (adventureService.ts:987-988). Seeded values range 10/8 up to 30/23 (e.g. `fitness_friends/backend/prisma/seed.ts:312`, `1052`). High risk is about 75% of standard.
- Skip: costs 0 stamina and 0 health (adventureService.ts:979-982).
- Guaranteed success (only on templates with `healthSpending.available`): standard stamina plus `healthSpending.cost` health (996-1010). Six seeded templates define `healthSpending` (seed.ts:410, 475, 544, 647, 1019, 1053).
- Train a stat during an adventure: 5 stamina, +1 to +3 points on one chosen stat, advances one turn (adventureService.ts:455-490). `Math.random()` picks the gain (473).
- Rest during an adventure: +10 stamina, +15 health, advances one turn (518-544). No cost.

**Breeding.** Costs no energy or resources. It requires two RETIRED creatures owned by the user, not the same creature, and not parent and direct child (`fitness_friends/backend/src/services/breedingService.ts:22-51`); output is a new EGG with inherited genetics (82-179). Retirement is a manual endpoint, `POST /v1/creatures/:id/retire` (`fitness_friends/backend/src/routes/creatureRoutes.ts:43-46`). `maxAge` is stored on creation (creatureService.ts:89,118) but no code compares `age` with `maxAge` to force retirement (grep of `maxAge` in `backend/src` shows only create and breed assignments and `calculateAgePenalty` in utils). `calculateAgePenalty` and `getTrainingGeneMultiplier` exist in `fitness_friends/backend/src/utils/genetics.ts:440,460` but are referenced by no other backend file (grep). So the README claim "Age penalties affect training efficiency" (README.md:116) is not wired in. Design intent for the age cost: age +1 per completed adventure (adventureService.ts:680-689).

**Other sinks:** `Item`, `InventorySlot`, `AdventureReward`, `Friendship`, `RouteEvent` models exist in the schema (schema.prisma:217-267, 373-384, 397-412, 455-470) but a grep of `backend/src` found no use of them. No currency, shop or items are spent anywhere. Monetization is only brainstormed (`fitness_friends/docs/MONETIZATION_IDEAS.md:1-100`); it rejects "energy systems that limit free play" (line 79).

## 4. Adventures and events

### Route model
`Route` (schema.prisma:273-304): `theme`, `terrainTags`, `difficulty` 1-5, `totalTurns` (default 10, line 282), `baseDistance` (deprecated), `skillChallengeChance`/`discoveryChance`/`restChance` (defaults 0.4/0.2/0.1), `minLevel`, `requiredRouteCompletions`.

Seven seeded routes (seed.ts:141-287): Whispering Woods (diff 1, minLevel 1), Emerald Trail (2, lvl 3), Azure Coast (2, lvl 5), Coral Depths (3, lvl 8, requires Azure Coast), Sky Peaks (3, lvl 10), Scorching Sands (4, lvl 12), Mystic Mountain (5, lvl 15, requires Sky Peaks and Scorching Sands). Fact: seed does not set `totalTurns`, so every seeded route uses the default of 10 turns. The first three routes set `restChance: 0.0` with a comment that REST events were removed (seed.ts:154, 175, 196).

Unlock check: level >= `minLevel` and all `requiredRouteCompletions` completed by this creature (`fitness_friends/backend/src/services/routeService.ts:134-154`).

### Starting an adventure
`startAdventure` (adventureService.ts:112-195): creature must exist and be ACTIVE, have no other ACTIVE adventure, and the route must be unlocked (126-140). Creates the adventure with `totalTurns` copied from the route, `currentTurn: 0`, `energyCost: 0`, `maxStaminaPool` from stamina stat, `currentStamina = max`, `currentHealth: 100` (155-174). Then it generates events (177).

### Event generation
`generateAdventureEvents` (adventureService.ts:200-324). It selects eligible `EventTemplate`s (enabled; theme match OR tag overlap OR no requirements; difficulty inside the template's min/max, 226-259). For each turn 1..totalTurns it rolls once (262-263) against cumulative chances in order skill, discovery, rest (267-315). Each roll yields at most one event, with a weighted random template of that type (329-342). If no template of that type is eligible, the turn gets no event (lines 271, 288, 303 guard on `length > 0`). Event types in the enum: SKILL_CHALLENGE, DISCOVERY, REST, TRAINING (schema.prisma:366-371). Templates are copied into `AdventureEvent.metadata` (JSON).

Fact: the seed contains no REST templates and no TRAINING templates (grep of `seed.ts` for `type: 'REST'` found nothing; all template types are SKILL_CHALLENGE or DISCOVERY). Routes 4-7 still have non-zero `restChance`, so those rolls produce no event.

### Event types and resolution
API: `POST /v1/adventures/:adventureId/events/:eventId/resolve` (`fitness_friends/backend/src/controllers/adventureController.ts:261-345`).

**SKILL_CHALLENGE** (adventureService.ts:930-1185), body `{action: attempt|skip|guaranteed, riskLevel: standard|high}`:
- Skill check (894-925): `roll = round(stat * (1 + uniform(-0.2, +0.2)))`. Threshold depends on the creature's stat: stat < 100 uses `difficultyThresholds.easy`, stat < 300 uses `.medium`, else `.hard` (909-915). `margin = roll - threshold`. Success if margin >= 0. It is critical if `|margin| >= 50` (standard) or `>= 30` (high risk) (918-922). Note: high risk lowers the crit bar for both crit success and crit failure.
- Success: XP and stat boosts from `rewards.success` or `rewards.critSuccess` (1074-1095). No health loss.
- Failure: lose `penalties.failure.health` or `.critFailure.health` (1123-1135); consolation XP = floor(success xp / 3) (or crit xp / 3 on crit failure) (1138-1146); if health hits 0 the adventure is set to ABANDONED (1149-1158). Failure grants no stat boost.
- Skip: marks resolved, grants floor(success xp / 2), costs nothing (962-984).
- Guaranteed: success rewards (not crit), costs stamina plus health (996-1058).
- Whatever the outcome, the event is marked resolved (1097-1100, 1160-1163).

**DISCOVERY** (1283-1352): no cost; XP and optional stat boosts from metadata; always success.

**REST** (1190-1278): service function restores `staminaRestore` and `healthRestore` plus rewards. But the controller rejects REST events with 400 `DEPRECATED_EVENT_TYPE` (adventureController.ts:323-333), so the service function is unreachable over the API. Inference: matches the seed comments that REST was converted to discovery.

### Turns, progress and completion
- `currentTurn` starts at 0 and only changes in `advanceTurn` (adventureService.ts:553-612), which is called by Train and Rest (484, 535). Resolving an event does not advance the turn: none of `resolveSkillChallenge`, `resolveDiscoveryEvent` or `resolveRestEvent` calls `advanceTurn`.
- Flutter decides what is "the current event" as an unresolved event with `turnNumber == currentTurn` (`fitness_friends/flutter_app/lib/models/adventure.dart:111-115`). Events are numbered from 1 (generation loop starts at turn 1, adventureService.ts:262) but `currentTurn` starts at 0.
- Inference: to reach any event the player must spend Train or Rest turns first, and an event appears only while the turn counter sits on its number. After resolving, the player must Train or Rest again to move on. I did not run this; this is derived from the code above.
- Completion: (a) `advanceTurn` completes the adventure when `newTurn > totalTurns` (574-577); (b) skip, guaranteed, successful attempt, discovery and rest call `checkAndCompleteAdventure`, which completes if every event is resolved (618-637). A failed attempt does not call it (1121-1184 end without the call), so an adventure whose last event is failed will not auto-complete there. (c) Health 0 sets ABANDONED. Inference: an adventure with zero generated events never auto-completes via (b); `every()` on an empty list is true, but the check is only reached after an event resolution, so it relies on (a).
- Completion reward: `xp = 50 * route.difficulty`; `level = floor(totalXP / 100) + 1`; `age += 1`; `adventuresCompleted += 1` (adventureService.ts:672-692). Only awarded when state was ACTIVE. `completeAdventure` is also exposed as an endpoint (`adventureRoutes.ts:44`).
- Abandon: manual `POST .../abandon` sets ABANDONED with no XP (718-753). Stat boosts and XP already earned in events stay.
- Dead endpoint: `POST /v1/adventures/:id/progress` (adventureRoutes.ts:26; controller `adventureController.ts:155-181`) calls `applyEnergyToAdventure`, which always throws "DEPRECATED" (adventureService.ts:355-362).

### Worked example (hypothetical event placement, real numbers)
Creature: the seeded "Sparky" (seed.ts:1159-1186): speed 35, stamina 30, level 3, 80 energy. Route: Whispering Woods (difficulty 1, 10 turns, skill 0.4, discovery 0.3, rest 0).

1. Start: `maxStaminaPool = min(100, 10 + floor(30/5)) = 16`. `currentStamina = 16`, `currentHealth = 100`, `currentTurn = 0`. Energy cost 0.
2. Generation (random): suppose turn 2 rolls skill (40%) and picks "Narrow Path" (primaryStat speed, thresholds easy 100 / medium 200 / hard 350, stamina 10 standard / 8 high, success xp 15 + speed 1, crit xp 30 + speed 2, failure -10 health, crit failure -20 health; seed.ts:296-322). Suppose turn 5 rolls discovery (30%) and picks "Forest Bounty" (xp 15, stamina +1; seed.ts:858-870). Both templates are eligible for forest with tags wooded and peaceful at difficulty 1 (seed.ts:302-306, 861-864).
3. The player Trains at turn 0 (-5 stamina, now 11; +1 to +3 speed, say +2 so speed 37) and the turn becomes 1. Trains again (stamina 6, speed maybe 39), turn 2. Narrow Path is now the current event.
4. Attempt standard: needs 10 stamina but only 6 remain, so it throws "Not enough stamina" (adventureService.ts:991-993). The player's options are Rest (+10 stamina to cap 16, +15 health, next turn), skip, or log a workout. Say the player logs a 30-minute run (60 EP) and applies it: stamina +30 (capped at 16, so back to 16), health +15 (capped at 100).
5. Attempt standard again at turn 2 with stamina 16: stamina to 6. Speed 39 is under 100, so threshold = easy = 100. Roll is 39 +/- 20%, so 31 to 47. Margin is -69 to -53; success needs margin >= 0, which is impossible. Margin magnitude is above 50, so critical. Result: critFailure, health -20 (100 to 80), consolation XP floor(30/3) = 10, event resolved.
6. Fact-derived finding: for any stat under 100 the best possible roll is `1.2 * stat`, and the lowest seeded `easy` threshold is 80 (Hidden Path, seed.ts:746). So success by attempt needs a stat of at least 67 at best, and most templates need more (easy thresholds 100-400, seed.ts:311, 340, 372...). Newly hatched creatures start around 10-35 per stat (seed.ts:1169-1173; README.md:113). Inference: early creatures cannot succeed by attempt. Their winning moves are skip, the six "guaranteed" templates, Training, and Discovery.
7. At turn 5 the discovery resolves free: XP +15 and stamina stat +1, no stamina or health cost (adventureService.ts:1283-1352).
8. Adventure ends when the turn counter passes 10 or all events are resolved; on completion XP is `50 * 1 = 50`, level is recomputed from total XP (150 + earned), age +1, `adventuresCompleted` +1 (adventureService.ts:672-692).

Seed vs code mismatch found while building the example: the skill-challenge `flavorText` in the seed is a plain string (e.g. seed.ts:309, 406), but `resolveSkillChallenge` reads `metadata.flavorText.skip/.success/.critSuccess` (adventureService.ts:806-812, 975, 1110-1111). With seeded data those lookups are `undefined`, so the success and skip result descriptions would be empty. Failure text works because it is read from `penalties.*.flavorText` (1170-1171). Inference only: I have not run it. The integration tests call these paths (`fitness_friends/backend/tests/integration/adventure.test.ts:471-590`) but I did not read them to see whether they build their own metadata.

## 5. Feedback to the user: pet reactions, messages, streaks, punishment

**What exists:**
- A 3-value mood enum: HAPPY, NORMAL, LIVELY (schema.prisma:201-205). Set to HAPPY when a creature hatches (creatureService.ts:262), when an applied activity produces a stat boost on the no-adventure branch (422), set to NORMAL at creation and breeding (111, `breedingService.ts:156`) and retirement (creatureService.ts:301). LIVELY is never assigned anywhere I found. Mood can also be changed by the client through `PATCH /v1/creatures/:id` (creatureController.ts:200-235).
- UI display of mood: only a text label in the creature detail header (`fitness_friends/flutter_app/lib/screens/creatures/creature_detail_screen.dart:323`). No animation or message is driven by mood.
- Activity apply feedback: a snackbar "<name> gained: Run +x, Swim +y, Power +z" (`fitness_friends/flutter_app/lib/screens/fitness/activity_history_screen.dart:161-182`). Mismatch: it reads keys `run`, `swim`, `power` but the backend returns `speed`, `stamina`, `power`, `flying`, `intelligence`, `energy`, `experiencePoints` (fitnessController.ts:305-313). Only power could match. Inference: after applying a run the snackbar will show an empty list after "gained:" (stats list `gainedStats` stays empty).
- Adventure result dialogs show XP, stat boosts, health lost (`adventure_screen_v2.dart` around 159; `event_resolution_card.dart`). Some of those widgets read `moodPenalty` and `moodBoost` metadata (adventure_screen_v2.dart:159; event_resolution_card.dart:166, 271, 370), but the backend `SkillChallengeMetadata` has no mood fields (adventureService.ts:805-848) and no backend code downgrades mood (the doc's `downgradeMood` at RESOURCE_SYSTEM_CHANGES.md:454-455 has no counterpart in `backend/src`; grep for `mood` in `backend/src` found no downgrade). So these UI strings are dead.
- The Flutter preview and the backend disagree on numbers: preview OTHER = 1.0 vs backend 0.8; preview distance bonus 0.5 EP per km vs backend 0.1 EP per km (0.01 per 100 m); preview shows stat labels "Run, Power" for running while backend boosts speed and stamina (`log_activity_screen.dart:33-34, 286`; `fitness_service.dart:129-143`; fitnessService.ts:46-72). The comment at fitness_service.dart:122 says it "matches the backend formula".
- Home screen is a static menu with text "Start by adopting your first creature, then log activities to help it grow stronger!" (`fitness_friends/flutter_app/lib/screens/home_screen.dart:139`). No daily goal, no progress, no creature on the home screen.

**What does not exist (NOT FOUND):**
- Notifications: `User.notificationsEnabled` and `soundEnabled` are columns (schema.prisma:26-27) and are set in the seed (seed.ts:1127-1128). A grep of `backend/src` and `flutter_app/lib` for notification, push, cron, streak, regen, decay, inactive, neglect found no implementation in the backend (the only matches were unrelated words like "punished" in genetics comments, `utils/genetics.ts:62`). Not found in the Flutter `pubspec.yaml` either (no notification package matched in my greps).
- Streaks: only a future idea (TECHNICAL_DEBT.md:296-300).
- Passive energy regeneration (+1 per 5 min or per hour, the two docs disagree: `ENERGY_SYSTEM_SUMMARY.md:53` says 5 min, line 212 and `04-adventure-gameplay-systems.md:226` say per hour) is designed but there is no cron or tick in `backend/src` (grep for cron and regen: none).
- Punishment for absence: none. Nothing decays, no mood drops with time, no creature falls ill, no loss of stats or progress. The only penalties in code are in-adventure health loss and stamina spending (section 3), and the creature's age, which rises only when adventures are completed (adventureService.ts:680-689), not with real time. The README's "Age penalties affect training efficiency" is not implemented (see section 3). Inference: the loop is entirely carrot (activity buys adventure resources and stats) with no stick; an inactive user just has a creature that stays where it is. Docs list "Rest bonuses" and "Fatigue system" only as future considerations (`ENERGY_SYSTEM_SUMMARY.md:188-196`).

## 6. Build status

Legend: Designed = doc path. Implemented = code path. Tested = test path. "none found" means I looked in `backend/tests` and `flutter_app/test` and did not find a test for it. Test counts are from `it(` grep counts in `backend/tests`.

| Feature | Designed (doc) | Implemented (code) | Tested |
|---|---|---|---|
| Fitness log (manual) | `docs/design/03-fitness-integration.md` | `backend/src/services/fitnessService.ts`, `controllers/fitnessController.ts`, `routes/fitnessRoutes.ts`; Flutter `screens/fitness/log_activity_screen.dart`, `activity_history_screen.dart` | `backend/tests/unit/services/fitnessService.test.ts`, `tests/integration/fitness.test.ts`; no Flutter test for fitness screens found |
| Energy (activity to EP, apply to creature) | `docs/design/ENERGY_SYSTEM_SUMMARY.md`, `03-fitness-integration.md:244-301` | `fitnessService.ts:84-96`, `creatureService.ts:339-434`, `adventureService.ts:374-424` | `tests/unit/services/creatureService.test.ts:523+` (applyEnergyToCreature), `fitnessService.test.ts`; `restoreAdventureResources` is in the `adventureService.test.ts` grep count, not individually verified |
| Energy: variable adventure cost | `ENERGY_SYSTEM_SUMMARY.md:63-89`, `04-adventure-gameplay-systems.md:77` | Removed: `adventureService.ts:89-93`, `163` | n/a |
| Energy: passive regeneration | `ENERGY_SYSTEM_SUMMARY.md:52-55`, `04-adventure-gameplay-systems.md:164-229` | NOT FOUND | none |
| Adventures (start, turns, train, rest, complete, abandon) | `docs/design/10-adventure-event-system.md`, `RESOURCE_SYSTEM_CHANGES.md` | `adventureService.ts`, `adventureController.ts`, `adventureRoutes.ts`, `routeService.ts`; Flutter `screens/adventure/adventure_screen_v2.dart`, `route_selection_screen.dart` | `tests/unit/services/adventureService.test.ts`, `tests/unit/controllers/adventureController.test.ts`, `tests/integration/adventure.test.ts`, `tests/unit/services/routeService.test.ts`; Flutter: none found for adventure screens |
| Events: skill challenge, discovery | `10-adventure-event-system.md:281-435`, `EVENT_SYSTEM_IMPLEMENTATION_PLAN.md` | `adventureService.ts:200-324, 894-1185, 1283-1352`; seed templates `prisma/seed.ts:292-1113` | same adventure tests (integration at `adventure.test.ts:419-590`) |
| Events: REST | `10-adventure-event-system.md:304-311` | Service function exists (`adventureService.ts:1190-1278`), blocked in controller (`adventureController.ts:323-333`), no seeded template | integration test "should resolve a REST event automatically" exists (`adventure.test.ts:534`); how it passes given the controller block was not read |
| Events: TRAINING type | not designed as event; enum only | `schema.prisma:370`; training done as an action `adventureService.ts:434-490` | not individually verified |
| Inspiration (reroll) tokens | `10-adventure-event-system.md:735-783` | NOT FOUND | none |
| Breeding | `docs/design/GENETICS_SYSTEM.md` (and archived `08-genetics-and-lifecycle.md`, referenced in `breedingService.ts:4`) | `backend/src/services/breedingService.ts`, `controllers/breedingController.ts`, mounted at `app.ts:90`; Flutter `screens/creatures/breeding_screen.dart`, `services/breeding_service.dart` | `tests/integration/breeding.test.ts` (14), `tests/integration/retirement.test.ts` |
| Genetics | `GENETICS_SYSTEM.md`, `genetics_v2_improvements.md`, `genetic_inheritance_guide.md`, `rare_allele_indicator.md` | `backend/src/utils/genetics.ts`, `types/genetics.ts`, `services/geneticsService.ts`; Flutter `models/creature.dart`, `widgets/rare_allele_indicator.dart` | `tests/unit/services/geneticsService.test.ts` (29), Flutter `test/models/creature_genetics_test.dart`. Training multiplier and age penalty functions (`utils/genetics.ts:440,460`) are unused elsewhere |
| Creator tool (Flutter) | `docs/design/CREATURE_CREATOR_TOOL.md`, `MODULAR_CREATURE_SYSTEM.md` | `flutter_app/lib/screens/creator/` (creator_screen, part_designer_screen, models, drawing_canvas, path_simplifier). Part persistence and modular system not built (CREATURE_CREATOR... per `DESIGN_DOCS_ASSESSMENT.md:202-216`, `186-199`) | none found under `flutter_app/test` |
| Auth | `01-architecture-overview.md`, `docs/process/15-backend-api-summary.md` | `backend/src/services/authService.ts`, `utils/jwtUtils.ts`, `middleware/authenticate.ts`; Flutter `services/auth_service.dart`, `login_screen.dart`, `register_screen.dart` | `tests/unit/services/authService.test.ts`, `utils/jwtUtils.test.ts`, `middleware/authenticate.test.ts`, `tests/integration/auth.test.ts`; Flutter `test/services/auth_service_test.dart`, `test/screens/login_screen_test.dart`, `test/integration/auth_flow_test.dart` |
| Health-platform sync (HealthKit/Google Fit/Fitbit) | `03-fitness-integration.md`, roadmap Phase 5 | NOT FOUND (only enum values and unused `FitnessConnection` model, `schema.prisma:56-75`) | none |
| Notifications / streaks | streaks: `TECHNICAL_DEBT.md:296-300` idea only; notifications: only user-setting columns (`schema.prisma:26-27`) | NOT FOUND | none |
| Items / inventory / rewards / friends | `06-development-roadmap.md` phases 4, 7 | Models only (`schema.prisma:217-267, 373-412`); no service or controller | none |

**Status claims in the docs disagree with each other (fact):**
- `README.md:154-159` says an energy-to-event transition is "~70% Complete" with four items "needed" (README.md:244-248, lines marked with an X). Code shows items 1, 3 and 4 are done: no energy cost at start (adventureService.ts:163), fitness restores adventure resources (creatureService.ts:365-378), completion by events (618-637). Item 2 (distance-based progression) is also gone from `completeAdventure`'s logic except for `currentDistance` UI fill (701). The README also lists `GET /v1/adventures/:id/current-event` (README.md:303) but no such route exists in `adventureRoutes.ts`.
- `fitness_friends/docs/design/06-development-roadmap.md:194-198` still says Phase 3 "NOT STARTED... no service/controller implementation yet" while the service and controller exist. `DESIGN_DOCS_ASSESSMENT.md` (dated 2025-11-05) rates `10-adventure-event-system.md` IMPLEMENTED and `04-adventure-gameplay-systems.md` "SEVERELY OUTDATED" (assessment lines 87-96, 133-147).
- README says 201 unit plus 61 integration = 262 tests (README.md:152, 225); my count of `it(` lines in `backend/tests` is 372. I did not run anything; the numbers are not reconciled. `COMPREHENSIVE_ROADMAP.md:383` says coverage 88.88% statements, 71.77% branches, and flags `adventureController.ts` at 33.33% (line 387), which is older than the 55-test `tests/unit/controllers/adventureController.test.ts` I found. Inference: the roadmap figure is stale.

## 7. Deployment

- Backend host: Render web service `fitness-friends-api`, free plan, Node runtime, region oregon, root `backend`; build runs `npm ci --include=dev && npx prisma generate && npx prisma migrate deploy && npm run build`, start `node dist/index.js` (`fitness_friends/render.yaml:1-9`).
- Env vars on Render: `DATABASE_URL` set manually to "your Neon connection string" (render.yaml:13-14), `JWT_SECRET` and `JWT_REFRESH_SECRET` auto-generated (15-18), `CORS_ORIGIN` set manually "to your Vercel frontend URL" (19-20), `LOG_LEVEL=info` (21-22). So the plan is Render (API) + Neon (Postgres) + Vercel (Flutter web frontend). Fact: the Vercel and Neon mentions are only comments in `render.yaml`; I found no `vercel.json` and no Vercel config (glob of the repo root). Inference: the Vercel frontend is intended, not shown to exist.
- Database: PostgreSQL required (Prisma `provider = "postgresql"`, `fitness_friends/backend/prisma/schema.prisma:8-11`). Local dev uses Docker Compose with `postgres:15-alpine` (dev DB on 5432 and test DB on 5433 using tmpfs) and Redis 7 (`fitness_friends/docker-compose.yml:4-50`). No `backend/src` file uses Redis (grep for redis in the files I read was only in docs and compose; not exhaustively checked).
- Auth model: username/email + password, bcrypt with 10 salt rounds (`backend/src/services/authService.ts:34-37`), JWT access token (default `7d`) and refresh token (default `30d`), secrets from env (`backend/src/config/env.ts:46-48`; `utils/jwtUtils.ts:40,56`). Routes use an `authenticate` middleware (e.g. `adventureRoutes.ts:12`). Flutter stores the token via `ApiService.setToken` (`flutter_app/lib/services/auth_service.dart:23-24`); the storage mechanism lives in `api_service.dart`, which I did not read in detail. Roadmap listed `flutter_secure_storage` as a task (COMPREHENSIVE_ROADMAP.md:120). Base URL defaults to `http://localhost:3000/v1`, overridable by dart-define (`flutter_app/lib/services/api_service.dart:10-12`).
- CORS: dynamic in development (any localhost port), strict list in production (`fitness_friends/docs/CORS-CONFIGURATION.md:11-22`).
- CI: GitHub Actions `backend-ci.yml` and `flutter-ci.yml` exist (`fitness_friends/.github/workflows/`); contents not read.
- Docs say "No deployment infrastructure yet" (`DESIGN_DOCS_ASSESSMENT.md:27`) and deployment documentation is missing (`COMPREHENSIVE_ROADMAP.md:411-416`), but `render.yaml` exists, so deployment was at least prepared after those notes. Whether it is live is NOT FOUND in the files.

## 8. Lessons

Only one real retrospective was found: `fitness_friends/docs/process/10-phase-0-lessons.md` (January 2024 header, line 3; note the roadmap says Phase 0 was completed in October 2025, `06-development-roadmap.md:46`, so the date looks like a typo). Also checked: `11-phase-0-summary.md`, `12-testing-status.md`, `13-phase-1-progress.md` exist but I did not read them in full.

What the author (Claude plus "SCoureFoure", line 4) said:
- **What worked** (lines 16-41): code organization, documentation quality, tooling setup (ESLint, Prettier, Jest, TypeScript), the Prisma schema ("11 models, proper indexes"), and a CI pipeline file.
- **What failed** (45-151): wrote about 2,000 lines without running anything; wrote a "COMPLETE" summary before verifying; skipped incremental testing; never ran a migration or queried the database; never started the server or hit `/health`. Stated takeaway: "'Compiles successfully' is not 'Works correctly'" (line 12). The "honesty gap" table says claimed 100% complete versus roughly 40% in reality (255-259).
- **Resulting rules** (211-232): test-first, run code within 15 minutes, test against a real database, honest status ("Built" is not "Complete"), commits under 200 lines.

Related process docs I did not read (names only): `02-testing-principles.md`, `03-commit-guidelines.md`, `04-code-clarity-principles.md`, `01-development-workflow.md`. Inference: the repo's own history shows the same "claimed done, actually partial" pattern the lessons doc warns about. For example, `06-development-roadmap.md` still reports the adventure system as not started, README says "Adventure UI (V2 - Ready to Deploy)" while `route_selection_screen.dart:126` already routes to `AdventureScreenV2`, and the Flutter apply-snackbar reads stat keys the backend does not send. `TEST_AUDIT.md` and `QUALITY_CHECKS.md` sit at the repo root; I did not read them.

## Doc vs code

| Doc claim | Code reality |
|---|---|
| Stamina pool is `min(100, floor(stamina/10))` (`RESOURCE_SYSTEM_CHANGES.md:67,187`; README.md:474; roadmap:489) | `min(100, 10 + floor(stamina/5))` (`adventureService.ts:105-107`) |
| Adventures cost 10-50 energy; passive regen (`ENERGY_SYSTEM_SUMMARY.md`, `04-adventure-gameplay-systems.md`) | Cost removed (`adventureService.ts:89-93,163`); regen not implemented; those docs are marked outdated in `DESIGN_DOCS_ASSESSMENT.md:87-96` |
| README says Yoga is an activity bonus (README.md:531) and "Stat range 10-1200" | No YOGA in `ActivityType` (schema.prisma:110-117); cap 1200 is in code (creatureService.ts:409) but `TECHNICAL_DEBT.md:78` says 200 |
| README says Skill Challenges 60%, Discoveries 20%, Rest 20% (README.md:100, 480-493) | Per-route chances vary: 40/30/0 on the first three routes, up to 55/10/3 on Mystic Mountain (seed.ts:152-154, 280-282) |
| README says "Can skip remaining events if out of stamina" (README.md:502) | Skip is available at any time at 0 cost (adventureService.ts:962-984) |
| Design: boost-roll option, `healthOptions`, stat boost chance, `skipOption` (`RESOURCE_SYSTEM_CHANGES.md:74-110`) | Not implemented; code uses `healthSpending` and fixed boosts from template (adventureService.ts:823-837) |
| `03-fitness-integration.md` formula: duration x multiplier, +0.1 per 100 m, steps and heart-rate bonuses | Code uses its own multipliers (RUN 2.0 vs doc 1.5), distance 0.01 per 100 m, no steps or heart rate (fitnessService.ts:45-96) |
| Design says retirement at max age and age penalties (README.md:108, 116) | `maxAge` never enforced; age penalty function unused (see section 3) |
| README: `GET /v1/adventures/:id/current-event` (README.md:303) | Route absent (`adventureRoutes.ts:12-65`) |
| Skill-challenge metadata has structured `flavorText` | Seed supplies a string (seed.ts:309); code reads sub-keys (adventureService.ts:975, 1110) |

## Open questions

1. Whether the seeded `flavorText` string actually breaks skip and success descriptions at runtime (tests may supply their own metadata). Needs a run or a read of `adventure.test.ts:419-600`.
2. How the turn counter and event numbering are meant to meet in play (events at turn N, `currentTurn` starts at 0, only Train and Rest advance). Intent versus bug is not settled in any doc I read; the gap-analysis doc is archived at `fitness_friends/docs/design/archive/ADVENTURE_IMPLEMENTATION_GAP_ANALYSIS.md` and I did not read it.
3. Whether a live Render, Neon or Vercel deployment exists. Only `render.yaml` and comments were found.
4. How the REST integration test passes while the controller rejects REST events (`adventure.test.ts:534` versus `adventureController.ts:323-333`).
5. The balance question the author left open: are the 2:1 and 4:1 conversion rates fair (`COMPREHENSIVE_ROADMAP.md:443-452`)? My worked example suggests the early-game stat/threshold mismatch is a larger balance issue, but that is an inference from one threshold per template and no play data.
6. Where `LIVELY` mood is meant to come from; it is never assigned in code.
7. Unread files: `docs/process/11`, `12`, `13`, `15`, `TEST_AUDIT.md`, `QUALITY_CHECKS.md`, the CI workflow files, `flutter_app/lib/services/api_service.dart` (token storage), `10-adventure-event-system.md` body, and the archived gap analysis.
