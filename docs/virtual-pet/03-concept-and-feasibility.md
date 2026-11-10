# Pet concept: outline and feasibility check

Status: concept only. Nothing is decided and nothing is being moved from fitness_friends yet. Section 1 is your idea as I understood it. Section 2 checks each part against what food-journal has today. Section 3 lists the risks I'd want ruled on before any spec.

---

## 1. The concept (as stated)

**Goal:** make *consistency* of food logging easier. The method is to project your own needs onto a small creature, so that a caregiving instinct kicks in even when you don't take care of yourself.

The loop:
1. **The creature eats what you eat.** It has a daily calorie need that is proportional to *your* calorie requirement. Logging a meal feeds it.
2. **What you eat shapes how it grows.** The mix of food logged affects which stats go up.
3. **Stats unlock things.** You need higher stats to do quests or finish challenges. This is the Fitness Friends idea, aimed at eating instead of exercise.
4. **Neglect has a cost.** Days without logged food make the creature weaker, and sustained neglect can kill it. That is the point: the stake is what makes consistency matter.

Borrowed from Fitness Friends: the *thought process* (input → points → stats → challenges), the creature renderer, and maybe the genetics. Not borrowed: its server, accounts or adventure code.

---

## 2. Feasibility, part by part

Overall: **technically feasible with no hard blockers.** Everything can run on the device with no backend, which fits food-journal's local-only rule. The real risks are design and product risks, not engineering ones (section 3).

### 2a. Feeding: the creature eats what you log — feasible, data exists

- Every food item already stores `calories`, `protein`, `carbs`, `fat` and `servings` (`app/lib/services/database/app_database.dart:28-34`). The home screen already sums a daily totals bar (`docs/FEATURES.md:32`). Intake per day is a query, not new tracking.
- **Gap: all four nutrition columns are nullable.** A meal where the AI parse failed or the user skipped the numbers would feed the pet nothing, even though it was a real meal. It needs a rule. One option is that a logged meal with unknown calories counts as an average portion.
- Hooking "a meal was logged" means wrapping `saveMeal` or watching the `meals` table (doc 02). Import and the debug seed call the same method and must not feed the pet.

### 2b. A need proportional to *your* requirement — feasible, but needs new data and a product decision

- **No profile exists.** An estimate of your daily calorie need (e.g. Mifflin-St Jeor plus an activity factor) needs height, age, sex and activity level. None of them are stored; `SettingsService` holds only AI on/off, left-handed mode, card state and the grocery draft. Weight *is* available from `weight_logs`, and new weigh-ins could keep the target current.
- The simplest version: the user types in a daily target, with an optional calculator later. A profile screen is more work but still modest.
- **Direct conflict with a written non-goal:** `docs/FEATURES.md:192` says *"No calorie goals or diet plans."* A creature that needs N calories a day is, functionally, a calorie goal. That isn't a technical blocker, but it is a product reversal. FEATURES.md would need an explicit amendment so that the spec process doesn't trip on it.

### 2c. Food shapes stat growth — feasible, but the inputs are thin

- The only nutrition axes available are **calories, protein, carbs and fat**. There is no fiber, sugar, sodium or micronutrient data, and the AI prompt doesn't produce any. Each would mean a schema change plus a prompt change.
- Signals that already exist and could also feed stats:
  - **Variety:** distinct `canonicalName` values over a week.
  - **Regularity:** meals spread across the day, from `meals.time`/`created_at`.
  - **Hydration:** `water_logs.amount_ml`.
  - **Check-ins:** `reaction_logs`, for example completing the "how did you feel" follow-up.
- Reusable from FF: the *shape* of `ACTIVITY_STAT_BOOST`, a table from input category to the stats it raises, plus a points → stat-point rule. FF's numbers don't transfer.
- **Design caution:** mapping macros to stats quietly says some food is better than other food (e.g. if fat raises nothing). That is the same "diet plan" territory as 2b. A balanced mapping, where every kind of eating feeds *something*, avoids it.

### 2d. Quests / challenges gated by stats — feasible, the largest build

- FF's adventure system can't be reused. It is server-side, has logic bugs (the turn counter, empty result text), and is unbalanced: new creatures can't pass early skill checks (doc 01). The *idea* carries over, but the code would be rewritten small and local.
- Its balance has to be designed, not ported. FF's main failure was thresholds that new creatures couldn't reach.
- A lighter variant to keep in mind: challenges that are themselves journaling goals ("log breakfast 5 days running"), with stats as the reward rather than the gate.

### 2e. Decay and death — feasible, and easy without a backend

- **No server tick is needed.** Hunger and decay can be computed on app open from "time since last feed". The creature "dies while the app is closed" simply because the elapsed time says so. This is simpler than FF, which never built time-based decay at all.
- **Warnings:** `flutter_local_notifications` is already a dependency and already schedules future notifications. A "your creature is hungry" nudge can be rescheduled on every log. Two existing issues come first:
  - There is no tap handler, so tapping a notification doesn't open anything specific.
  - Meal *N* and medication *N* share a notification id, so they can overwrite each other.
- **Exploit surface:**
  - Meals can be **backdated** (`meals.date` is user-picked), which could retroactively feed a starving creature.
  - **Deleting** a meal removes it, which could un-feed one.
  - Changing the device clock could fake time passing. That matters little for a single-player app.
  - Each of these needs a rule. A likely one: feeding counts at `created_at`, with a short grace window for legitimate late logging.
- **Death:** the renderer already draws an egg, so "death → new egg" is cheap. FF's genetics could make the new egg inherit from the old creature, which gives death some meaning without being a dead end.

### 2f. Showing it — feasible, with partial reuse

- FF's `CreatureFlameWidget` drops in (doc 01). One useful fit: it already takes a `customProportions` override, so **body condition** (thin when underfed, round when well fed) could be shown by scaling the existing proportions. That is a near-free visual for hunger.
- New work: expressions and states such as hungry, sad, sleepy, weak and dead. FF only animated a bob and never showed mood.

---

## 3. Risks to rule on before a spec

These matter more than any engineering question.

1. **Incentive to log falsely.** food-journal's core value is honest data for finding symptom triggers. A starving creature gives the user a reason to log food they didn't eat, or to inflate portions. That would corrupt the blame and suspect analysis the app exists for. The more the creature depends on *calorie amount*, rather than on *the act of logging*, the stronger that pull.
2. **Logged-little vs. ate-little.** The creature can't tell "I didn't log lunch" from "I didn't eat lunch". Your goal is consistency, so the two coincide, which is useful. But it means a calorie-proportional need also judges *how much* you ate. A day of honest light eating would show a hungry creature.
3. **Over-target days.** If the need tracks your requirement, what happens when you exceed it? Neutral? An overfed or sluggish creature? Any penalty here is diet-plan territory.
4. **Who is this for?** For someone who under-eats or forgets meals, a creature that needs feeding is the exact caregiving nudge you describe. For someone with a history of restrictive eating, calorie targets and a body that visibly changes can be a trigger. One option is a setting that drops the calorie-proportional part and feeds the creature on logging alone.
5. **Absence that isn't neglect.** Illness, travel, a fasting day for a medical test. Is there a pause or "boarding" mode, or is death strict?
6. **The non-goal amendment.** Section 2b. This is your call, recorded in FEATURES.md.

---

## 4. Revision (2026-11-05): the pet as a proxy for the user

New direction: **the user also gets calorie (and maybe macro) goals**, as a real feature, not just a number inside the pet. The creature is a projection of *your* needs. That has two consequences.

### 4a. User calorie goals: a standalone feature that the pet depends on

- **This settles risk 6:** the non-goal "No calorie goals or diet plans" gets amended. The amendment should say what changes, for example: "Calorie and macro goals: yes. Prescriptive diet plans or meal prescriptions: still no."
- **The goals feature has value without any pet:**
  - The daily totals bar (`docs/FEATURES.md:32`) gains "of target" progress.
  - Weekly averages vs target.
  - Macro split vs target.
- **Inputs:**
  - A profile with height, age, sex and activity level, for an estimate such as Mifflin-St Jeor. The alternative is a manual target, or both, with manual overriding the estimate.
  - Weight already comes from `weight_logs`, so the estimate can follow new weigh-ins.
- **One storage subtlety:** the pet judges *past* days against the target *as it was that day*. If you change your goal in March, February's feeding must not be re-scored. So targets need **history**, either a small `goal_history` table (schema v17) or effective-dated rows. A single SharedPreferences number isn't enough. The profile itself could stay in settings.
- **Ordering:** goals come *before* the calorie-proportional pet layer, and they're their own spec (`specs/calorie_goals.spec.md`).

### 4b. The creature is bothered by what bothers you — feasible, and the machinery already exists

food-journal already has a trigger-detection system, which the pet can read rather than reinvent:
- **The blame ledger:** each feeling check-in fans out suspicion rows (`food_suspicions`) to the foods eaten in a time window before it. These are weighted by symptom level (mild=1, moderate=2, bad=3), with manual blame ×3, and they decay with age (`app/lib/models/food_suspicion.dart:142-187`).
- **Ranked suspects** per symptom: rate = score ÷ times eaten, with a minimum of 3 check-in episodes, and dismissals excluded (`specs/blame_suspects.spec.md`, decisions 2026-10-20). Read through `StorageService.getSuspects`.
- Foods match by `canonicalName`, so "the pet ate milk" and "milk is a suspect for Bloating" can be joined directly.

How it could tie together:
- When a logged meal contains a current suspect, the creature reacts to the same symptom: bloated, sluggish or queasy. One option is that it also gets less benefit from that meal.
- **The creature's sensitivities are learned from your check-ins.** That closes a second loop: feeling check-ins become *useful to the pet*, not just to the analysis. Check-ins are the app's hardest-won data, so this pushes on the right behavior.
- Dismissing an episode (already supported) would also clear it from the creature.
- **Bonus: the pet makes false logging self-defeating** (partly answering risk 1). Fake entries feed the pet today but poison its sensitivities tomorrow, so honest logging is what keeps the creature well.

Cautions:
- **Suspects are correlations, not diagnoses.** The creature's reaction should be mild and explanatory ("Pip seems bloated — milk has shown up before your bloating 4 times"), not a punishment that teaches you to fear food. The tone ought to go into the spec.
- **Cold start:** nothing qualifies until 3 check-ins exist for a food and symptom. A new user's creature has no sensitivities, which is honest, and the creature can show it is "still learning about you".
- Medications are suspects too (AC8 merges food and medication). Does the creature react to your meds? That's a design choice.

### 4c. Architectural consequence: the creature is mostly a *view over your journal*

If needs = your goals, sensitivities = your suspects, and hunger = your logging, most pet state can be **derived** from journal data instead of stored separately. Only a little has to be stored: birth/death events, genome, and stats accrued.
- **For derived state:** it survives export/import, can't drift out of sync, and is easy to test as pure functions (the repo's testing style).
- **Against derived state:** backdating or deleting a meal rewrites the creature's history, so a creature could "un-die".
- That is the same `date` vs `created_at` fork as in 2e. The likely answer is a hybrid: derive the needs, but record feeding and death as events at the moment they happen.
- This is a design fork for the spec, not decided here.

---

## 4d. Rendering direction (2026-11-05)

- **2D, not 3D.** The feel is a mini Tamagotchi plus a Clippy-style corner companion that reacts to what you just logged and talks in a speech bubble. The bubble is ordinary Flutter UI, not a rendering problem.
- **Chosen starting asset:** the Craftpix "free pixel art tiny hero sprites" pack, **Pink_Monster**. Location: `C:\Users\SCora\Downloads\free-pixel-art-tiny-hero-sprites\1 Pink_Monster\`. It isn't in the repo yet; when it's needed, copy it in together with its license.
- **Format:** horizontal PNG sprite strips. Frames are 32×32: the height is 32px, and the width is 32 × the frame count, per the pack's readme. The frame count is in the file name (`Pink_Monster_Idle_4.png` = 4 frames). Strips: Idle 4, Walk 6, Run 6, Jump 8, Climb 4, Push 6, Throw 4, Hurt 4, Death 8 (ends as a ghost), Attack1 4, Attack2 6, Walk+Attack 6.
- **Mapping to pet states:**

| Pet state | Source |
|---|---|
| idle | `Idle_4` |
| happy / just fed | `Jump_8` |
| bloated / reacting to a suspect food | `Hurt_4` |
| death | `Death_8` |
| hungry, weak, sleepy | none — fake it with code effects: slower frame rate, desaturation, a "Zzz" or "?" bubble |
| eating | none — overlay a food icon on idle, or draw custom frames |
| egg / hatching | none — custom art or a simple drawn egg |

- **License (read 2026-11-05):** the Craftpix "Freebie products" terms (section 2 of `https://craftpix.net/file-licenses/`).
  - **Allowed:** personal and commercial use, modification, and selling or distributing the app with the art in it. Attribution is not required, but credit is appreciated.
  - **Forbidden: redistributing the raw files.** That has three consequences here:
    - Committing the PNGs to a **public** repo would make them downloadable. Keep the repo private, or keep the art out of public git.
    - Don't add a feature that lets the user save or export the creature artwork, such as "share your pet as an image" or bundling the sprites into the JSON export.
    - Ordinary in-app display is fine.
  - **Forbidden: any AI use (section 3).** The assets and *any derivative works* may not be used to train, develop, test or improve AI or generative systems. So:
    - **Don't generate the missing frames (eating, sleeping, egg) with an image AI** from these sprites. Draw them by hand, e.g. in Aseprite.
    - Never send sprite images through the Gemini Worker.
- **Playback:** pixel art should be drawn with nearest-neighbour filtering (`FilterQuality.none`) at whole-number scales so it stays crisp. A plain Flutter frame ticker is enough. Flame's `SpriteAnimation` is an option only if Flame is added for other reasons.

## 5. A build order to consider (prove, then add one thing)

Revised for 4a/4b. Each layer is usable on its own, and each tests one claim:

| Layer | Adds | Claim it proves |
|---|---|---|
| 0 | **User calorie goals** (profile and/or manual target, history, "of target" on the totals bar). No pet | Goals are useful to the user by themselves |
| 1 | Creature + hunger from *logging meals* + decay + death/new egg | "A creature that suffers when I don't log makes me log more." This is the core bet |
| 2 | Hunger proportional to the user's target (needs layer 0) | Proportional feeding feels right and doesn't distort logging |
| 3 | **Shared sensitivities:** the creature reacts to your suspect foods (reads `getSuspects`) | Tying the pet to your triggers drives check-ins without breeding food fear |
| 4 | Food → stat growth (macros, variety, regularity) | What you eat shaping the creature is fun, not judgmental |
| 5 | Challenges/quests gated by stats | Stats give long-term purpose beyond survival |
| 6 | Inheritance on death/egg (FF genetics port) | Losing a creature feels meaningful rather than punishing |

Layers 0 and 1 don't depend on each other. Layer 1 still leaves calories out, so it isolates the caregiving hypothesis. Layer 3 moved up ahead of stats because it reuses a working system (blame suspects) and reinforces the most valuable behavior (check-ins). It needs only a read of existing data and a few creature reactions.

**Scoreboard for the core bet:** journaling consistency is already measurable from existing data, as distinct days with any entry per week (doc 02). Take your own baseline from current data before the pet exists, then compare. That answers "did the pet work" with a number.
