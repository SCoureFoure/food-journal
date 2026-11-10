# fitness_friends: creature core (data and rules)

Paths are repo-relative with the `fitness_friends/` prefix. "Fact" is seen in code or docs. Lines starting `Inference:` are my reading.

Short version: a creature is one Prisma row (`creatures`) plus a `genetics` JSON blob. Genetics is the V2 float-allele system in `src/utils/genetics.ts` and `src/types/genetics.ts`. `src/services/geneticsService.ts` is an older V1 integer-allele system that nothing calls (see Doc vs code).

## 1. Creature fields

Source: `fitness_friends/backend/prisma/schema.prisma:123-199`. Flutter mirror: `fitness_friends/flutter_app/lib/models/creature.dart:43-206`.

| Field | Type | Default | Meaning |
|---|---|---|---|
| id | String (uuid) | generated | Primary key (`schema.prisma:124`) |
| userId | String | none | Owner; cascade delete with user (`:125-126`) |
| name | String | none | Display name. Adoption defaults to "New Egg" (`creatureController.ts:44`); bred eggs are named "Egg" (`breedingService.ts:134`). Hatch can rename (`creatureService.ts:263`) |
| generation | Int | 0 | Distance from wild stock; offspring = max(parents)+1 (`utils/genetics.ts:298`) |
| primaryColor, secondaryColor | String | none | Hex colors. Stored separately from genetics (`schema.prisma:132-133`) |
| pattern | String | none | Pattern name (`:134`) |
| accessories | String[] | [] | Cosmetic ids; nothing in the creature code writes them |
| genetics | Json? | null | The `CreatureGenetics` object (section 3) (`:138`) |
| speedPhenotype .. lifespanPhenotype (6 columns) | Float? | null | "Computed phenotype for querying" (`:140-147`). Never written (see Doc vs code) |
| inbreedingCoefficient | Float? | 0.0 | Column exists (`:148`). Never written; the value lives inside the genetics JSON |
| lineageName, lineageId | String? | null | Bloodline tags (`:151-152`). Never written by any service I found |
| speed, stamina, power, flying, intelligence | Int | 10 each | Gameplay stats. Comment says range 0-1200 (`:154-159`) |
| mood | enum Mood | NORMAL | HAPPY, NORMAL, LIVELY (`:201-205`). LIVELY is never assigned in the code I read |
| health | Int | 100 | Creature-level health (`:163`). See section 2 |
| energy | Int | 100 | Creature-level energy, cap 100 (`:164`, `creatureService.ts:398`) |
| state | enum CreatureState | EGG | EGG, ACTIVE, RETIRED (`:207-211`) |
| experiencePoints | Int | 0 | Accumulated XP (`:168`) |
| level | Int | 1 | Derived from XP at adventure completion (`adventureService.ts:678`) |
| age | Int | 0 | Count of completed adventures, not time (`:172`) |
| maxAge | Int | 50 | Adventure cap from lifespan gene (`:173`) |
| adventuresCompleted | Int | 0 | Total completed adventures (`:174`). Incremented with age at `adventureService.ts:690`, so it duplicates `age` |
| totalDistanceTraveled | Float | 0 | Lifetime meters (`:175`). Only ever set to 0 at creation (`creatureService.ts:120`, `breedingService.ts:168`); no update found |
| hatchedAt | DateTime? | null | Set on hatch (`creatureService.ts:261`) |
| retiredAt | DateTime? | null | Set on retire (`creatureService.ts:300`) |
| parentAId, parentBId | String? | null | Self-relation to parents, `onDelete: SetNull` (`schema.prisma:180-185`) |
| createdAt, updatedAt | DateTime | now / auto | Timestamps (`:190-191`) |

Indexes: userId, state, speedPhenotype, staminaPhenotype, lineageId (`:193-197`).

Fact: the Flutter model lacks the phenotype columns, lineage fields and `inbreedingCoefficient` as top-level fields. It carries `genetics` as an untyped `Map<String, dynamic>?` (`creature.dart:51`). Stats are grouped into a `CreatureStats` class with `health` included (`creature.dart:209-250`). It has one helper that reads genetics: `rareAlleleCount` from `genetics['rareAlleles']` (`creature.dart:195-202`).

## 2. Stats

Five trainable stats: speed, stamina, power, flying, intelligence. Plus health (0-100) and energy (0-100) as separate resource values.

**Starting value (fact).** `BASE_STAT 10 + floor((phenotype - 1.0) * 5)` per stat (`utils/genetics.ts:426-434`). Phenotype is the max of the two alleles, allele bounds are 0.2-2.5 (`types/genetics.ts:234-235`).
- Inference: starting stats therefore run from 6 (phenotype 0.2) to 17 (phenotype 2.5). The design doc claims 7-12 (`archive/08-genetics-and-lifecycle.md:421`), which assumed the old 0.5-1.5 gene range.

**Range.** Schema comment says 0-1200 (`schema.prisma:154`). The cap of 1200 is enforced only in the activity path (`creatureService.ts:409-417`). Adventure training and event rewards add with no cap (`adventureService.ts:479`, `:1024-1027`, `:1085-1088`). Design doc 02 says 0-100 base, 0-200 soft cap (`02-data-models.md:319-320`), which is stale.

**What raises stats (facts).**
1. Fitness activity applied to an ACTIVE creature with no active adventure (`creatureService.ts:339-433`):
   - `statBoost = floor(energyPoints / 10)`, split evenly with floor across the activity's stats (`:382`, `:405`).
   - Stat map: RUNNING and CYCLING give speed+stamina; SWIMMING stamina+power; WALKING stamina+intelligence; STRENGTH power+flying; OTHER intelligence (`fitnessService.ts:65-72`).
   - Also adds energy (cap 100) and XP equal to floor(energyPoints). Sets mood HAPPY if any boost applied (`:398-399`, `:422`).
2. Same activity while an adventure is active: no creature change. Energy goes to the adventure's stamina/health pool via `restoreAdventureResources` (`creatureService.ts:365-378`).
3. Adventure "train" action: costs 5 adventure stamina, adds random 1-3 to one chosen stat (`adventureService.ts:455-481`).
4. Adventure event rewards: `statBoost` maps from event metadata, applied on success or guaranteed action (`adventureService.ts:1022-1034`, `:1083-1095`, `:1243-1250`, `:1321-1328`).

**What changes XP and level.** Completing an adventure gives `50 * route.difficulty` XP; level = `floor(totalXP / 100) + 1` (`adventureService.ts:672-678`). Event rewards add more XP (`:1079`, `:1144`).

**What uses stats.** Adventure stamina pool = `min(100, 10 + floor(stamina / 5))` (`adventureService.ts:105-107`). Event skill checks read the creature's stats (`performSkillCheck`, called at `:1070`; body not read by me).

**Health and energy.**
- Fact: creature `health` is set to 100 at creation and never written afterward by the services I read. Adventure health is a separate per-adventure field (`currentHealth`, `adventureService.ts:167`).
- Fact: creature `energy` is only changed by activities (`creatureService.ts:398`). Nothing spends it. `startAdventure` charges no energy (`adventureService.ts:163`).
- Doc vs code: see section 5 for the regeneration claim.

**Age penalty and training multiplier (dead code).** `calculateAgePenalty` (`utils/genetics.ts:460-472`) and `getTrainingGeneMultiplier` (`:440-455`) are defined but have no callers in `src/` (grep). Activity stat boosts do not use them.

## 3. Genetics

**Representation (fact).** One JSON object `CreatureGenetics` (`types/genetics.ts:69-105`):
- Numeric traits, each an `AllelePair = [number, number]`: speed, stamina, power, flying, intelligence, lifespan (`:77-82`).
- Visual traits, each a pair of enum values: bodyType (10 values), color (8 palettes), pattern (7 values) (`:85-87`; enums `:13-52`).
- Cached phenotype for each of the 9 traits (`:90-98`).
- `generation`, `parentAId`, `parentBId`, `inbreedingCoefficient` (`:71-74`).
- `mutations: string[]`, `rareAlleles: string[]`, optional `lineageId`, `lineageName` (`:101-104`).

**Allele values (fact).** Float 0.2 to 2.5 (`GENETICS_CONFIG`, `types/genetics.ts:228-236`). Rarity bands (`:215-222`):

| Band | Range | Declared weight |
|---|---|---|
| DEFECT | 0.2-0.6 | 5% |
| POOR | 0.6-0.8 | 10% |
| COMMON | 0.8-1.4 | 69.75% |
| UNCOMMON | 1.4-1.7 | 15% |
| RARE | 1.7-2.0 | 1% |
| ULTRA_RARE | 2.0-2.5 | 0.25% |

Generation: roll once, walk bands in order accumulating weight, then pick uniformly in the band (`utils/genetics.ts:152-166`).
- Inference: the weights sum to 1.01, so the cumulative total passes 0.9975 only at the RARE step; ULTRA_RARE is unreachable by random generation (roll < 1 always lands in RARE or earlier), and RARE effectively gets 0.25%, not 1%. Ultra-rare values can still arise by mutation, since the clamp max is 2.5 (`:100-106`).

**Dominance (fact).**
- Numeric traits: complete dominance, phenotype = `Math.max(allele0, allele1)` (`utils/genetics.ts:53-55`). A 1.9/0.3 pair expresses 1.9 and hides the weak allele.
- Visual traits: each enum value has a dominance rank (`types/genetics.ts:165-197`). Higher rank wins; equal rank is a coin flip (`utils/genetics.ts:191-204`). Ranks: color VOLCANIC 5, FIRE and SHADOW 4, EARTH and NATURE 3, WATER and SKY 2, CRYSTAL 1; pattern SOLID 5 down to SWIRLS and MARBLE 1; body type ATHLETIC and BALANCED 5 down to aquatic and avian 2.
- Fact: `inheritVisualGene` rolls a 10% mutation (`VISUAL_MUTATION_RATE`, `types/genetics.ts:200`) that replaces the result with a random value. This runs when the phenotype is computed, and the result is stored in the cache. Inference: the stored phenotype can therefore differ from what the alleles alone predict, and recomputing it later would give a different answer.

**Phenotype to looks (fact).** `colorPhenotype` and `patternPhenotype` and `bodyTypePhenotype` are stored in the genetics JSON. For hatchlings from breeding, `primaryColor`/`secondaryColor` come from a fixed 8-entry palette table keyed by `colorPhenotype` (`breedingService.ts:61-77`, `:139-141`). Only two hex colors per palette. Pattern copies `patternPhenotype` (`:141`).
- Fact: adopted gen-0 eggs do NOT do this. They use `primaryColor || '#4ECDC4'`, `secondaryColor || '#FFD93D'`, `pattern || 'solid'` (`creatureService.ts:92-94`) regardless of genetics.
- Fact: the Flutter renderer has genetics-aware widgets (`widgets/creature_flame_widget.dart`, `widgets/creature_body_components.dart` mention genetics); I did not read them, so how they pick colors is NOT FOUND in this slice.

**Inheritance (fact).** For each numeric trait, one random allele from each parent (50/50 each), then each allele has a 5% chance to mutate by a random amount within +/-20% of its own value, clamped to 0.2-2.5 (`utils/genetics.ts:39-43`, `:95-107`, `:304-317`). For visual traits, one random allele from each parent, no per-allele mutation, then the 10% phenotype mutation above (`:339-352`).

**Rare alleles (fact).** After inheritance, every numeric allele whose value falls in the RARE or ULTRA_RARE band is recorded as `"<trait>_allele1"` or `"_allele2"` in `rareAlleles` (`utils/genetics.ts:240-256`, `:354-370`). Only the six numeric traits are checked. The Flutter UI shows a star from the array length (`creature.dart:195-205`, `widgets/rare_allele_indicator.dart`).

**Inbreeding (fact).** `calculateInbreedingCoefficient` returns 0.25 for full siblings, 0.125 for half siblings, else 0 (`utils/genetics.ts:116-143`). It only reads the parent ids stored in genetics. No penalty is applied; the penalty table is all zeros and `applyInbreedingEffects` is unused (`utils/genetics.ts:57-75`, `types/genetics.ts:264-288`). Inference: a parent-child or grandparent pair would score 0, but parent-child is blocked at validation.

**Genotype shape in docs only.** Docs describe training genes of 0.5-1.5 and a lifespan gene of 0.5-2.0 (`archive/08-genetics-and-lifecycle.md:109-116`). Constants `LIFESPAN_GENE_CONFIG` and `TRAINING_GENE_CONFIG` still exist but are unused (`types/genetics.ts:152-162`).

## 4. Breeding

Entry: `POST /breeding/breed` -> `breedingController.breedCreatures` (`breedingController.ts:16-79`) -> `breedingService.breedCreatures` (`breedingService.ts:82-179`).

**Inputs.** `parentAId`, `parentBId` from the body; `userId` from the auth token.

**Rules (`validateBreeding`, `breedingService.ts:22-51`).**
1. Both parents must be RETIRED (400).
2. Both must belong to the caller (403).
3. A creature cannot breed itself (400).
4. A parent cannot breed its direct child (checks parent ids both ways) (400).
5. Both must have genetics JSON (400) (`:109-111`).
- Not checked: siblings, grandparent/grandchild, inbreeding threshold, generation limits. Same-owner only; no friend breeding despite the docs' "future" note.

**Cooldowns and costs.** NOT FOUND. Searched `breedingService.ts`, `breedingController.ts`, `schema.prisma` (no cooldown field), and `src/` for "cooldown" and "cost". Parents are not consumed or flagged after breeding, so the same pair can breed repeatedly with no limit.

**Output (fact).** One new creature row in state EGG (`breedingService.ts:132-176`):
- name "Egg"; generation = max(parents)+1; genetics from `inheritGenetics` with `parentAId`/`parentBId` set (`:114-120`).
- stats from `calculateInitialStats`; `maxAge` from `calculateMaxAge(lifespanPhenotype)` = `floor(50 * lifespanPhenotype)` (`utils/genetics.ts:412-414`). Inference: this gives 10 to 125 adventures.
- mood NORMAL, health 100, energy 100, level 1, XP 0, age 0.
- colors and pattern from phenotype via palette table (section 3).
- `parentAId`/`parentBId` set on the row. `lineageId`, `lineageName` and the six phenotype columns are not set.
- Response is the raw Prisma row with HTTP 201 (`breedingController.ts:68`).

**Other endpoints.** `GET /breeding/retired` lists the user's retired creatures (`breedingService.ts:184-194`). `GET /breeding/stats/:creatureId` returns offspring count and list; the controller checks ownership after loading (`:199-227`, `breedingController.ts:173-189`).

## 5. Lifecycle

States: EGG -> ACTIVE -> RETIRED (one-way). Egg to retired is blocked.

| Transition | Rule | Source |
|---|---|---|
| (create) EGG | Adoption or breeding | `creatureService.ts:114`, `breedingService.ts:155` |
| EGG -> ACTIVE (hatch) | Explicit user call; fails if not EGG. Sets `hatchedAt`, mood HAPPY, optional rename. No timer, no cost | `creatureService.ts:242-268` |
| ACTIVE -> RETIRED | Explicit user call; fails if already RETIRED or still EGG. Sets `retiredAt`, mood NORMAL | `creatureService.ts:277-306` |

**Age.** `age` counts adventures, not days. It goes up by 1 when an adventure completes in the ACTIVE state; abandoned adventures give nothing (`adventureService.ts:670-692`). The code comment says "1 day per adventure" (`:680`), which is misleading.

**Forced retirement at maxAge: not implemented.** Searched `src/` for `maxAge`/`retire`: only creation code, the retire function and the `RetirementReason` enum reference them. `completeAdventure` does not compare `age` to `maxAge`. The design doc requires it (`archive/08-genetics-and-lifecycle.md:68-71`, `:94-96`). `RetirementEvent` and `RetirementReason` types exist (`types/genetics.ts:117-134`) but are unused. Inference: a creature can exceed `maxAge` indefinitely until the user retires it.

**Time-based decay if the user is absent: NOT FOUND.** No cron, scheduler, or interval in `src/` touches creatures (grep for setInterval/cron/schedule returned no hit in services). Nothing reduces stats, health, energy or mood over wall-clock time. `02-data-models.md:330` claims passive energy regeneration (e.g. 1 per hour) but no code does it. `08-genetics-and-lifecycle.md:638-640` also claims energy regenerates over time; same result. The only time-based effects are `hatchedAt`/`retiredAt` timestamps.

**Warnings.** Doc proposes 80% and 90% maxAge messages (`archive/08-genetics-and-lifecycle.md:721-726`); no code found.

## 6. Adoption

Fact: the first creature is not automatic. Registration does not create one (`adoptCreature` is called only from `creatureController.ts:46`). The user taps "Add Egg" on the creature list (`flutter_app/lib/screens/creatures/creature_list_screen.dart:65`, `:201`), which POSTs an empty body to `/creatures` (`flutter_app/lib/services/creature_service.dart:9-16`). Home screen text says "Start by adopting your first creature" (`home_screen.dart:139`).

Server then (`creatureService.ts:76-125`):
1. `generateRandomGenetics()` (gen 0, six numeric pairs, random visual pairs, rare tracking) (`utils/genetics.ts:213-289`).
2. `calculateInitialStats` and `calculateMaxAge`.
3. Creates an EGG row: generation 0, level 1, XP 0, health/energy 100, mood NORMAL, colors from request or defaults.

No limit on how many eggs a user can adopt, no cost, no cooldown (none found in `creatureService.ts` or the controller). The user then hatches via `POST /creatures/:id/hatch` (`creature_service.dart:102`).

Inference: the body can still carry `primaryColor`, `secondaryColor`, `pattern` and the server uses them (`creatureController.ts:25`, `:46-52`). The Flutter client sends nothing, so defaults apply. A second adoption screen file still exists (`creature_adoption_screen.dart`) that the simplification doc said to delete.

## 7. Server dependency

**Needs server state (database or auth):**
- All state transitions: adopt, hatch, retire, rename/mood update (`creatureService.ts:76-306`). They write rows and check ownership.
- Ownership checks (`isCreatureOwner`, `creatureService.ts:315-324`; `validateBreeding` rule 2).
- Breeding eligibility: needs both parent rows' `state`, `userId`, parent ids (`breedingService.ts:22-51`). The genetics math itself does not need the DB.
- Offspring-count and retired-list queries (`breedingService.ts:184-227`).
- Applying activity energy: needs the creature row, the activity record, and whether an active adventure exists (`creatureService.ts:339-434`). The stat formula (`floor(energy/10)`, split by activity stats, caps) is arithmetic only.
- Adventure-completion side effects: XP, level, age, adventuresCompleted (`adventureService.ts:643-693`). Level formula is pure; reading the route's difficulty needs the DB.
- Training and event rewards (`adventureService.ts:434-490`, `:1014-1095`). Random rolls happen server-side (`Math.random`), so a device version would be unauthenticated.
- Anything that must be unforgeable or shared between devices: allele rolls at adoption and breeding. Inference: they could run on device, but then a client could pick its own alleles. They stay server-side unless the game is single-player.

**Could run on device (pure, no DB or HTTP):** the genetics math, stat formulas and level formula. Listed in section 8.

**Client already does:** parse JSON, `isEgg`/`isActive`/`isRetired`, rare-allele count (`creature.dart:185-205`).

## 8. Portability: pure functions

All TypeScript unless noted. "Randomness" = uses `Math.random`, which would need an injectable RNG for deterministic tests.

| Function | path:line | Notes |
|---|---|---|
| `inheritAlleles` | `fitness_friends/backend/src/utils/genetics.ts:39` | Mendelian pick; randomness |
| `calculatePhenotype` | `utils/genetics.ts:53` | Pure; `max` of pair |
| `getInbreedingLevel` | `utils/genetics.ts:80` | Pure thresholds |
| `applyInbreedingEffects` | `utils/genetics.ts:68` | Pure, deprecated, always penalty 0 |
| `applyMutation` (allele) | `utils/genetics.ts:95` | Randomness; uses `GENETICS_CONFIG` |
| `calculateInbreedingCoefficient` | `utils/genetics.ts:116` | Pure; reads parent ids from genetics |
| `generateRandomAllele` | `utils/genetics.ts:152` | Randomness; rarity table |
| `generateRandomAllelePair` | `utils/genetics.ts:171` | Randomness |
| `getAlleleRarity` | `utils/genetics.ts:178` | Pure |
| `inheritVisualGene` (private) | `utils/genetics.ts:191` | Randomness; needs dominance maps |
| `generateRandomGenetics` | `utils/genetics.ts:213` | Randomness; whole gen-0 genome |
| `inheritGenetics` | `utils/genetics.ts:294` | Randomness; whole offspring genome |
| `calculateMaxAge` | `utils/genetics.ts:412` | Pure |
| `calculateInitialStats` | `utils/genetics.ts:419` | Pure |
| `getTrainingGeneMultiplier` | `utils/genetics.ts:440` | Pure, unused |
| `calculateAgePenalty` | `utils/genetics.ts:460` | Pure, unused |
| `calculateMaxStaminaPool` (private) | `fitness_friends/backend/src/services/adventureService.ts:105` | Pure; stat to pool |
| `validateBreeding` | `fitness_friends/backend/src/services/breedingService.ts:22` | No DB inside, but takes Prisma `Creature` and throws `AppError`; swap those two types to port |
| `getColorsFromPalette` (private) | `breedingService.ts:61` | Pure lookup; has only 8 palettes |
| `calculateEnergyPoints` | `fitness_friends/backend/src/services/fitnessService.ts:84` | Pure per its signature (`ENERGY_PER_MINUTE` table not read here) |
| `ACTIVITY_STAT_BOOST` | `fitnessService.ts:65` | Constant table |
| `encodeGenotype`, `decodeGenotype` | `fitness_friends/backend/src/services/geneticsService.ts:264`, `:283` | Pure but belong to the unused V1 genotype |

Constants and types to copy with them: everything in `fitness_friends/backend/src/types/genetics.ts` (enums, dominance maps, `ALLELE_RANGES`, `GENETICS_CONFIG`, `BASE_LIFESPAN`). `types/genetics.ts` has no imports. `utils/genetics.ts` imports only from it, so the pair copies as-is. Only `breedingService.ts` and `creatureService.ts` pull in Prisma.

Not portable as-is: `adoptCreature`, `hatchCreature`, `retireCreature`, `applyEnergyToCreature`, `breedCreatures` (all do DB reads and writes inline). The state rules inside them are short and can be lifted by hand: hatch needs state==EGG; retire needs state==ACTIVE; stat boost is `floor(floor(E/10)/numStats)` per stat, cap 1200.

Dart side: no genetics logic exists in Dart. Dart would need a port of the table above.

## Doc vs code

1. `GENETICS_SYSTEM.md` says "Implemented", implementation in `geneticsService.ts`, integer alleles 1-10, stat = max*3 (`GENETICS_SYSTEM.md:3-5`, `:49-73`). Code reality: `geneticsService.ts` has no importers (`derivePhenotype`/`breedGenotypes` only appear in that file). Live code uses `utils/genetics.ts` with float alleles 0.2-2.5 and `CreatureGenetics`. Its own table row "Rare Alleles: not implemented" (`:402`) and "Inbreeding: field exists, not calculated" (`:403`) are also stale; both are implemented in `utils/genetics.ts`.
2. `GENETICS_SYSTEM.md:375` says phenotype DB columns are "schema ready, not populated". Still true: no code writes `speedPhenotype` etc.
3. `rare_allele_indicator.md:23-25` claims ~46% of creatures have a rare allele and that alleles >=1.7 are rare. Declared weights are RARE 1% and ULTRA_RARE 0.25% per allele over 12 alleles (6 traits x 2), giving about 12% at best; with the weight-sum issue in section 3 it is roughly 3%. `types/genetics.ts:211` itself says "~14% of creatures".
4. `archive/08-genetics-and-lifecycle.md` describes training genes, averaged inheritance, forced retirement at maxAge, totalDistanceTraveled updates, and 7-12 starting stats. Code has no training genes, uses Mendelian pairs, does not force retirement, never updates `totalDistanceTraveled`, and starts at 6-17.
5. `archive/egg_adoption_simplification.md` says colors/pattern params should be removed and genetics should drive color. Code still accepts and applies them (`creatureService.ts:77`, `:92-94`), and adopted eggs never get genetics-derived colors; bred eggs do.
6. `02-data-models.md` shows a different Creature shape (`appearance`, `stats.swim/fly/run`, `parentCreatureId`, stats 0-100). Schema differs on all of these.
7. Energy: docs say passive regeneration over real time and energy spent to start adventures (`02-data-models.md:328-331`, `08-...:637-641`). Code spends none and regenerates none.
8. `completeAdventure` comment says "1 day per adventure" (`adventureService.ts:680`); age is adventure count per schema and docs.

## Open questions

- Whether any code outside `src/` (scripts, seeds, tests) populates the phenotype columns or lineage fields. I only searched `backend/src` and the named docs.
- How the Flutter renderer picks creature colors (genetics vs stored `primaryColor`): the widgets named above were not read.
- `performSkillCheck` (`adventureService.ts`) was not read, so exactly which stats feed adventure success is not confirmed.
- Whether forced retirement at maxAge is intentionally deferred or just missing (no TODO found).
- Whether the RARE weight-sum bug (ULTRA_RARE unreachable by generation) is known; tests for it were not searched.
- `ENERGY_PER_MINUTE` and the exact body of `calculateEnergyPoints` past line 94 were not read.
