# Fitness Friends: what's actually there

Research only. Nothing has been moved or changed in either repo. This is a picture of `fitness_friends` as it stands today (last commit 2026-03-27, about 7 months dormant). It is written to answer one question: what could a food-journal pet borrow from it?

The detailed reports, with `path:line` citations for every claim, are in `research/`:
- `research/ff-creature-core.md`: creature data, stats, genetics, breeding, lifecycle
- `research/ff-creature-render.md`: how creatures are drawn and animated, plus the creator tool
- `research/ff-loop.md`: the fitness-to-pet loop, adventures, build status, deployment, lessons
- `research/fj-surface.md`: food-journal as the host (summarised in doc 02)

---

## One-paragraph summary

Fitness Friends is a Chao-Garden-style pet app. It is a Flutter client on a Node/Express + Prisma + Postgres backend, with JWT accounts, built to deploy on Render, Neon and Vercel. You log a workout by hand. The backend turns it into "energy points", and you apply those points to one creature. The points either refill an adventure's stamina and health, or add energy, XP and stat points to the creature. Creatures have a real genetics system: float alleles, dominance, mutation, rare alleles and breeding. They are drawn procedurally with Flame. Health-platform sync, notifications, streaks, time-based decay and forced retirement were all designed but never built. The adventure system has several logic bugs, and newly hatched creatures can't win its early skill checks.

## What exists, by layer

| Layer | Status | Portable to food-journal? |
|---|---|---|
| **Creature rendering** (Flame + Canvas, ~1,220 lines) | Works. Fully procedural: no image assets. 10 body types plus an egg, 8 colour palettes, 7 patterns | **Yes, the best candidate.** It needs only `flame`, `creature.dart` and two widget files. No providers, services or HTTP. Both apps use the same Dart SDK constraint (`^3.9.2`) |
| **Genetics math** (`backend/src/utils/genetics.ts` + `types/genetics.ts`) | Works. It is pure TypeScript with no imports beyond its own types file | Logic yes, but it is **TypeScript only**. No Dart port exists, so using it in food-journal means porting it |
| **Creature model/rules** (adopt, hatch, retire, stats) | Works on the server. State machine: EGG → ACTIVE → RETIRED | The rules are small enough to rewrite by hand. The service code is Prisma-bound |
| **Breeding** | Works. Both parents must be retired; no cost and no cooldown | Probably not relevant (see doc 02) |
| **Fitness → energy conversion** | Works. `EP = minutes × multiplier + tiny distance bonus` | The *shape* transfers (entry → points → pet). The numbers don't |
| **Adventures and events** | Partly works, with bugs (below) | No. It is server-heavy and unbalanced |
| **Mood** | Enum HAPPY/NORMAL/LIVELY. Shown only as **text** on the detail screen and never drawn. LIVELY is never set | The concept yes, but the visuals would be new work |
| **Notifications, streaks, decay, health sync** | Designed only. No code | Nothing to borrow |
| **Creator tool** | A proportion editor and a freehand part designer. Output is Dart code copied to the clipboard, and the app can't read it | A dev aid at most. It has preview bugs |

## The rendering layer in a bit more detail

This is the piece most worth knowing well:

- **Widget API:** `CreatureFlameWidget({required Creature creature, double width = 200, double height = 200, BodyProportions? customProportions})`.
- **What drives the look:** three strings in `creature.genetics`: `bodyTypePhenotype`, `colorPhenotype` and `patternPhenotype`. Secondary colour is derived from the primary. The stored `primaryColor`/`pattern` columns are explicitly ignored. I checked that the backend enum strings match the Flutter switch cases exactly.
- **Body families:** quadruped, biped, aquatic, avian and egg. Each family is one component class with proportion presets, not mix-and-match parts.
- **Animation:** one sine-wave bob, sway or breath per family, running continuously. There is no blink, no expressions, no reaction to taps and no mood visuals. For a journaling pet, expressive states are the part you'd most want, and they would all be new work.
- **Known quirks:**
  - The quadruped draws its front and back legs at the same coordinates, so only 2 legs show.
  - A new `CreatureGame` is built inside `build()`, so a parent rebuild may reset the animation (not verified at runtime).
  - Each creature gets its own Flame game, which is heavy in a list. The list screen already uses a Material icon instead.
- **Tests:** 4 shallow widget tests. None of them check pixels.
- **A possible simplification:** the drawing is plain `Canvas` code. The five components could be ported to a `CustomPainter` driven by a `Ticker`, which would drop the Flame dependency entirely. This hasn't been tried.

## Genetics in brief

- Each of the six numeric traits (speed, stamina, power, flying, intelligence, lifespan) is an allele pair of floats from 0.2 to 2.5. The higher allele wins (`max`).
- Body type, colour and pattern are enum allele pairs with dominance ranks. The phenotype also has a 10% chance of mutating to a random value.
- Breeding passes one random allele from each parent. Each allele has a 5% chance to mutate by ±20%.
- Rare alleles are tracked and shown as a star badge.
- **Bug:** the rarity weights sum to 1.01, so random generation never produces ULTRA_RARE, and RARE comes out at about 0.25% instead of 1%.
- **Dead code:** a V1 integer-allele system (`geneticsService.ts`) is still in the repo, and `GENETICS_SYSTEM.md` still describes it as the live one.

## The engagement loop, and what it lacks

FF's loop gives rewards and nothing else:

1. You log an activity by hand. Steps, calories and heart rate are stored but ignored.
2. You get points.
3. You manually apply them to a creature.
4. Stats go up and mood becomes HAPPY.

Nothing happens if you stop: no decay, no sad pet, no reminder, no streak. A dormant user's creature just sits there. Doc 02 matters here, because the open design question for a journaling pet is mostly about **what happens when you don't log**, and FF offers no precedent for it.

## Bugs and mismatches worth knowing about (if anything is ever lifted)

These come from the reports and are inferred from reading the code. None were confirmed by running it.

**Adventures**
- `currentTurn` starts at 0, but events are numbered from 1. Resolving an event never advances the turn; only Train and Rest do.
- Early creatures can't pass skill checks. Stats start around 10–35, the roll is at most 1.2 × stat, and the easiest seeded threshold is 80.
- The seeded `flavorText` is a plain string, but the code reads `.success` and `.skip` sub-keys from it, so those result messages would come out empty.
- REST events are blocked in the controller, but the docs and some routes still expect them.

**Client vs backend**
- The Flutter "apply" snackbar reads stat keys (`run`, `swim`) that the backend doesn't send.
- The Flutter energy preview uses different multipliers from the backend.

**Creature lifecycle**
- `maxAge` is never enforced. `totalDistanceTraveled`, the lineage fields and the phenotype columns are never written.

**Creator tool**
- The preview always draws a quadruped, because the mock creature's body type ends in `_custom`.
- The standalone `tool/` copy ignores its sliders.

## Project lessons the author recorded

`docs/process/10-phase-0-lessons.md` is an honest retrospective: about 2,000 lines were written without running anything, and the work was marked "COMPLETE" before it was verified (claimed 100%, really about 40%). The resulting rules were test-first, run within 15 minutes, test against a real DB, and keep "Built" separate from "Complete". The repo's docs still show that pattern: several design docs describe features as live when they don't exist. **Practical upshot: trust the code, not the FF docs.**
