# Kickoff — Kitchen: the household inventory between shopping and eating

> Status: kickoff (not a spec) · Created 2026-10-19
> Broad strokes agreed with the user. Each phase below becomes its own spec via
> `/spec` before it is built. Builds on `specs/receipt_scan.spec.md` and
> `specs/meal_planning.spec.md`.

---

## The idea

Most food apps make food appear out of nowhere: you take a picture, the app guesses on
the spot. Real life does not work that way. At home you eat what is already in the
house, and the house is refilled by shopping. Shopping and eating are one step removed
from each other, and the household inventory sits between them:

```
shop ──► kitchen (what's in the house) ──► eat (journal) ──► insights
 ▲                                                              │
 └──────────── grocery list (achievable, routine-aware) ◄───────┘
```

Like crafting in a game: ingredients come in from the store, meals are made from them,
and you eat parts of the meal. Because routines repeat, the kitchen becomes an exact,
local lookup table of what this person actually buys and eats. That is the app's
unique angle, and it extends what already exists (receipt scan, saved-item composer,
grocery list) rather than replacing anything.

## Principles

1. **Fit the day, don't add chores.** The builder does not log every meal; one photo is
   already friction. Anything that asks for entry at the moment of eating or cooking will
   fail on arrival. The kitchen fills itself from receipts; logging gets faster because of
   it, never slower.
2. **The kitchen informs the AI; it does not fence it in.** When a meal is described or
   photographed, the AI sees what is in the kitchen and prefers those names when they fit
   what it sees. It must never force a kitchen item onto a photo that does not show it.
   Eating out is the obvious case: a restaurant photo has nothing to do with the pantry.
3. **Presence, not counts.** An item is in the kitchen or it is not. Its existence makes
   it selectable. No quantity bookkeeping, no decrementing, no unit math in v1.
4. **Reuse the existing screens.** Review, correction and manual entry use the modals and
   editors the app already has.
5. **AI-optional, local-first, low-dependency** — unchanged.

## Navigation

Three folder tabs: **Journal | Kitchen | Planning**.

- **Journal** — unchanged.
- **Kitchen** — what is in the house: pantry items, receipt queue and review. Later,
  cooked dishes.
- **Planning** — the weekly plan and the grocery list. The nutritionist's advice is to
  plan meals ahead and pick from a menu instead of logging reactively; Planning
  reinforces that habit, before and after shopping.

The pantry card currently on the Planning tab moves to Kitchen.

## What a "pantry item" is

A food the user has bought, tagged as a pantry item so it is visibly "the thing I
bought, from my house". It carries:

- a clean name and canonical key (shared with journal food names and blame);
- the receipt spellings it has appeared as (aliases), so the next receipt fills itself in
  without AI: `PROG TRD CHK ORZ LMN` → "chicken orzo soup";
- present / not present;
- when it was last bought and how often (purchase history, for insights).

**Incoming items are diffed against existing ones.** When a receipt line looks like an
existing pantry item (same alias, or a close name match), review proposes "same thing?"
instead of creating a duplicate. Lines that are hard to parse go to the same review list
for manual correction.

### Identity and repeat purchases (phase 2 requirement)

**Assume a repeat purchase first.** At least half of a typical shop is things bought
before, and staples repeat most. Matching an incoming line to an existing pantry item is
the expected case; creating a new item is the exception. The pantry never shows
"peanut butter" and "peanut butter 2".

**One pantry row per unique food.** Identical lines on one receipt already merge into a
single review row with a summed quantity. What the phase 2 spec must add:

1. **Bought again on a later trip** → the existing item is marked present again and its
   purchase history grows. No new row.
2. **OCR misread of a known line** (`PROG TRD CHK 0RZ LMN` vs `... ORZ ...`) → matches
   the known alias, not a new item.
3. **Close match** → review asks: "Peanut butter matches a pantry item. Bought it again,
   or is this a different peanut butter?" One tap keeps it as the same item; the other
   makes a new one. The answer is remembered as an alias, so it is not asked again.

**How fine-grained an item is.** Rule: split only on what changes the diet or a reaction.

| Same item (merge by default) | Different items (never merge silently) |
| --- | --- |
| Brand: Jif vs Skippy peanut butter | Lactose-free milk vs whole milk |
| Pack size, store brand vs name brand | Flavour that adds an ingredient: black cherry skyr vs plain skyr |
| Texture with the same ingredients: chunky vs smooth | Gluten-free, sugar-free, dairy-free, decaf variants |

Flavoured is not plain. A flavour can carry an allergen or a trigger, so "black cherry
yogurt" is its own item, not "yogurt". Plain yogurt is "yogurt".

**Recognise first, then group.** The first pass still identifies the specific product
("Jif peanut butter", "Skippy peanut butter") and keeps that detail on the purchase
record and as an alias. The pantry item it files under is the generic food ("peanut
butter"). The user can always split an item or rename it; their choice wins over the
default rule. Splitting matters to some users (texture, brand), and the default must not
fight them.

**Regression fixtures.** The phase 2 spec carries a fixture of receipts over time (the
same staples on several trips, a misread line, a brand swap, a flavour change, a
lactose-free swap) with the expected pantry after each one, so matching never silently
regresses.

### Schema note

`pantry_items` (v16) exists only on the unmerged `feat/receipt-scan` branch and stores
one row per receipt line with a quantity. It ships to nobody yet, so it should be
reshaped **before merge** to the model above rather than migrated later: one row per
pantry food (identity, presence, aliases) plus a purchase-event row per receipt line.
Exact shape is decided in the phase 1 spec.

## How the AI uses the kitchen

- `parse_meal` (text or photo) receives a short "In the kitchen:" context block, the same
  way it already receives "Recent meals:" for leftovers. Guidance: use a kitchen name when
  the item clearly matches; otherwise name what you see.
- `parse_receipt` already receives "Known foods:". Pantry names and aliases join that
  list.
- **Home vs out.** Whether a meal was eaten at home matters (only home meals should lean
  on the kitchen), but adding it as a field is a schema change that may not be needed.
  Open fork: an optional home/out marker on meals, inferred or one tap, versus letting the
  AI judge from the photo. Decide in the phase 3 spec, not before.

## Grocery lists

Bias the generated list toward pantry items. If you bought it before, your store
carries it, so the list is achievable. Later, insights add:

- bought often and eaten often → staple, keep on the list;
- bought but rarely eaten → waste, suggest dropping;
- reaction-flagged foods → warn before buying;
- missing macros / goals → suggest what to add ("you're eating, but not eating well").

## Phases (order agreed; each gets a spec)

1. **Receipt queue + speed.** Snap several receipts; they read in the background while
   the app is in use; the Kitchen shows "N reading… / N ready to review"; you review each
   one (approve or edit lines). Photos wait only in the app's private cache and are
   deleted once read. Fix the scan speed first (batch recogniser calls, return argmax
   from native code instead of ~6 MB of scores per line, use more CPU threads, measure on
   the phone).
2. **Kitchen tab + pantry items.** Third tab; pantry as present/not-present items with
   aliases and purchase history; repeat-purchase matching and the "same thing?" prompt
   per *Identity and repeat purchases*, with its regression fixtures; manual add and
   edit through existing editors. Reshape `pantry_items` before merging the branch.
3. **Kitchen-aware logging.** Pantry names in `parse_meal` context; pantry items offered
   in the journal's food search; home/out fork decided here.
4. **Grocery list from the kitchen.** Pantry bias, restock suggestions, bought-vs-eaten.
5. **Insights.** Waste, staples, reaction flags on stock, macro gaps toward goals.

## Deferred: cooked dishes and servings

Turning pantry items into a cooked dish with servings (a pot of soup eaten over three
days) is the natural next layer and the hardest one. Open questions, to spec before any
build:

- How much was made? How much is one serving? Who enters that, and when?
- Calories for the whole pot from its ingredients, then per serving eaten.
- Leftovers thrown away break the math. Does it matter, or is "roughly right" enough?
- Does the saved-item composer (smoothie, PB & fluff sandwich) become the recipe?

Until then the backstop stands: the AI builds meals from what it sees and what the user
types. Manual entries and saved items can carry servings later. This also revisits
`specs/meal_planning.spec.md` decision 19 (fork G, meal prep deferred).

## Open forks (rule before the phase that needs them)

| Fork | Needed by | Options |
| --- | --- | --- |
| Home vs out marker on meals | phase 3 | optional field (inferred or one tap) · AI judges from the input · none |
| Pantry item vs journal food identity | phase 2 | shared canonical key only · pantry item id linked from food items |
| When an item stops being "present" | phase 2 | manual "used up" · not bought for N weeks · eaten N times · never automatic |
| Kitchen context size for the AI | phase 3 | all present items · top N by recency/frequency |
