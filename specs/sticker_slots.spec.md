# Spec — Sticker slots: an end-of-day spin that turns logging into pet rewards

> Status: idea · Feature: sticker_slots · Added: 2026-11-25
> Concept capture, not a build contract. Nothing here is pinned until the open questions
> are ruled and `stickers` (layer 1) has shipped and felt good on its own.

## Requirement

The stickers (`specs/stickers.spec.md`) are the carrot that keeps the user logging. This
idea gives them a second job: each sticker earned during the day becomes a **symbol on a
slot machine reel**. At the end of the day the user **spins once**. The more the user did
that day (logged meals, logged water, weighed in, synced the watch, moved), the richer the
reel pool and the better the expected payout. The payout is **coins** for a **virtual shop**
where the user buys things for the pet: pieces for its space, toys, treats.

The aim is to use a **variable reward schedule**. The amount the user gets for a day isn't
known in advance, and that uncertainty is what makes the end-of-day spin something to look
forward to. Doing more raises the odds without guaranteeing the jackpot. It sits on top of
the existing loop: nudges are the stick (`pet_nudges`), stickers are the immediate carrot,
and the spin is the delayed, variable carrot.

## Constraints (inherited)

- **Positive-only (stickers, pet_nudges):** a spin never takes anything away. No losing
  spin, no coin cost to spin, no lost streak or lost items. A thin day still spins and still
  pays something.
- **Honesty-first / ED safety (virtual_pet doc 03 §3.1, §3.4):** symbols reward the *act of
  logging* and balanced goals, never eating less or more. A met calorie target is worth no
  more than "logged a meal" or "drank water". No food is a "good" or "bad" symbol.
- **Not gambling:** no real money in or out, no buying spins, no buying coins, no ads. One
  spin per day, earned only by that day's activity. No fake near-misses: the reel shows the
  outcome it actually rolled.
- **Derive what can be derived:** the day's symbols come from data the journal already holds
  (entries, goal history, watch samples). Only the spin result, the coin balance and the
  owned items need storing.
- **Own art only:** symbols are the stickers' own code-drawn pixel icons. Shop items are
  original pixel art in the `PetBlock` style.
- **AI-optional:** no AI anywhere in this feature.

## Sketch (unpinned — the shape of the idea)

- **Earning symbols during the day.** Each qualifying act adds one symbol to today's pool,
  e.g. meal logged, water logged, weigh-in, feeling check-in, watch synced (today has
  biometrics), steps goal met, a goal metric met, a streak milestone. Several of one act may
  add up to a cap, so logging three meals beats logging one but logging ten does not beat
  logging three.
- **The reel.** The reel strip is a fixed base set (a few plain "pet paw" symbols, so a spin
  always pays something) plus today's earned stickers. More earned stickers means more
  distinct symbols, which means more chances to line up matches.
- **The spin.** Available once the day is done: from a set evening time, or the next
  morning for yesterday. Unspun days roll over for a short window (e.g. 3 days) and then
  expire quietly with no message about it.
- **Payout.** Coins by match type: base payout for any spin, more for a pair, a lot for three
  of a kind, with a rare jackpot. Expected coins rise with the size of the day's pool. The
  odds and payout table live in one pure function so they can be tested and tuned.
- **The shop.** Coins buy pet things in three groups: **space** (floor, wallpaper,
  furniture for the pet's corner), **toys** (the pet plays with them), and **treats**
  (one-off: the pet eats it and reacts). Prices are set so a typical logged day buys a
  treat, and a good week buys a furniture piece.
- **Where it lives.** The spin is an action on the pet sheet ("Spin today's stickers"), and
  the shop is a second section of that sheet. The pet's space appears where `PetBlock`
  is drawn.

## Open questions (rule before this becomes a build spec)

1. **Order of layers.** Recommend: ship `stickers` v1 (today-only, derived) first, then a
   persisted sticker book, then the spin, then the shop. Each one has to feel good before
   the next is added.
2. **Which acts earn symbols**, and the per-act cap.
3. **When the spin unlocks:** a fixed evening time, the next morning for yesterday, or both.
4. **Rollover window** for an unspun day, and whether an expired day is ever mentioned
   (recommend: never mentioned).
5. **Payout table and odds:** base payout, pair / triple / jackpot amounts, jackpot rarity.
6. **Shop catalogue v1:** how many items, which groups first (recommend treats first: no
   placement UI needed).
7. **Does the watch count as an act?** Syncing is a tap in Gadgetbridge, not a journal
   action. Recommend: "today has biometrics" counts as one symbol.
8. **Storage:** a new table for spin results and coin ledger, and one for owned items
   (schema change, migration test).
9. **Pet reactions:** does the pet react to a spin result, and to a treat or toy?

## Acceptance criteria

Deferred until the open questions are ruled. Expected seams to test once pinned:
- a pure `symbolsForDay(...)` (what the day earned),
- a pure `spin(pool, rng)` with an injected RNG (deterministic payout tests),
- the coin ledger (a balance never goes below 0, a spin can't be claimed twice),
- the shop purchase (a coin debit and an owned item land together, or neither does).

## Anchors (explore rig)

To be assigned with the build spec (expected: `btn-spin-day`, `spin-result`,
`pet-shop`, `shop-item-<id>`, `coin-balance`).

## Verifies-with

To be written with the build spec.

## Related

- `specs/stickers.spec.md` — the symbols' source (layer 1).
- `specs/virtual_pet.spec.md`, `specs/pet_nudges.spec.md` — the pet and the stick half of
  the loop.
- `specs/watch_import.spec.md` — biometrics as an earnable act.
