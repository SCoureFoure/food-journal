import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_entity.dart';

// Tests the pure entity-resolution core: canonicalize (the storage/ledger key)
// and bestNameMatch (the reuse-nudge matcher). No native sqlite — the SQL paths
// that delegate here are covered on-device. See specs/food_entity_resolution.spec.md.

void main() {
  group('[EQUIV] canonicalize — format variants collapse to one key', () {
    // testTheory: equivalence-class — case, surrounding/internal whitespace, and
    // punctuation are all noise on top of the same canonical identity.
    // contract: canonicalize is the single normalization stored in canonical_name
    //   and used by the matcher.
    // implication: AC8 (blame accumulates) only holds if these all map equal.
    test('AC1 — case/whitespace/punctuation variants all map equal', () {
      const variants = [
        'Turkey Sandwich',
        'turkey  sandwich',
        'turkey-sandwich',
        '  Turkey sandwich. ',
        'TURKEY   SANDWICH!!!',
      ];
      for (final v in variants) {
        expect(canonicalize(v), 'turkey sandwich', reason: 'variant: "$v"');
      }
    });

    test('AC2 — distinct foods keep distinct non-empty keys', () {
      final a = canonicalize('turkey sandwich');
      final b = canonicalize('tuna sandwich');
      expect(a, isNotEmpty);
      expect(b, isNotEmpty);
      expect(a, isNot(b));
    });

    test('AC4 — unicode letters + digits survive, single-spaced', () {
      expect(canonicalize('Café 50g'), 'café 50g');
      expect(canonicalize('Vitamin D3'), 'vitamin d3');
    });
  });

  group('[BVA] canonicalize — empty/garbage boundaries', () {
    // testTheory: boundary — empty, whitespace-only, and punctuation-only are the
    // degenerate inputs the storage seam must not turn into a junk bucket.
    // contract: such inputs canonicalize to '' so callers can guard.
    // implication: AC14 (matcher returns null on garbage) rides on this.
    test('AC3 — empty / whitespace-only / punctuation-only → ""', () {
      expect(canonicalize(''), '');
      expect(canonicalize('   '), '');
      expect(canonicalize('!!!'), '');
      expect(canonicalize(' - / . '), '');
    });
  });

  group('[MFT] bestNameMatch — reuse nudge selection', () {
    // testTheory: meaningful-function — the matcher decides whether a fresh entry
    // gets steered onto an existing entity, and which one.
    // contract: returns the best candidate at/above threshold, skipping ones that
    //   are already canonical-identical; null otherwise.
    // implication: drives the inline reuse chip (AC15–AC17).
    test('AC10 — close wording variant matches above threshold', () {
      final m = bestNameMatch(
        'turkey sandwich w/ mayo',
        const ['Turkey Sandwich', 'Tuna Salad'],
      );
      expect(m, isNotNull);
      expect(m!.candidate, 'Turkey Sandwich');
      expect(m.score, greaterThanOrEqualTo(kNudgeThreshold));
    });

    test('AC11 — unrelated name returns null', () {
      final m = bestNameMatch('oatmeal', const ['Turkey Sandwich', 'Tuna Salad']);
      expect(m, isNull);
    });

    test('AC12 — canonical-identical candidate is skipped', () {
      // Same entity already — nothing to nudge toward.
      final m = bestNameMatch('turkey sandwich', const ['Turkey  Sandwich']);
      expect(m, isNull);
    });

    test('AC13 — highest score wins; ties resolve to most-recent (first)', () {
      // Candidates passed most-recent-first. "chicken rice bowl" shares 2/3 tokens
      // with "chicken rice" (0.66) and 2/4 with "chicken rice soup" (0.5).
      final m = bestNameMatch(
        'chicken rice bowl',
        const ['chicken rice', 'chicken rice soup'],
      );
      expect(m, isNotNull);
      expect(m!.candidate, 'chicken rice');

      // Exact tie → first (most-recent) candidate wins.
      final tie = bestNameMatch(
        'apple banana',
        const ['apple cherry', 'banana cherry'], // each 1/3 with typed
        threshold: 0.3,
      );
      expect(tie, isNotNull);
      expect(tie!.candidate, 'apple cherry');
    });

    test('AC14 — empty / punctuation-only typed input returns null', () {
      expect(bestNameMatch('', const ['Turkey Sandwich']), isNull);
      expect(bestNameMatch('!!!', const ['Turkey Sandwich']), isNull);
    });
  });

  // ── Data-shape coverage: real-world food/med name variants ──────────────────
  // Probed against the live fn, then pinned. Documents both the collapses we
  // rely on AND the lexical limits we accept (so they're contracts, not bugs).
  group('[EQUIV] canonicalize — real-world name shapes collapse', () {
    // testTheory: equivalence — accents, separators, symbols, and emoji are
    // surface noise; the same item must reach one key across realistic typings.
    // contract: canonicalize is locale-insensitive case-fold + punct→space + collapse.
    // implication: blame buckets survive how the AI/user happens to format a name.
    final cases = <List<String>>[
      ['Café latte', 'CAFÉ LATTE', 'café latte'],        // accent + case
      ['Coca-Cola', 'coca cola', 'coca cola'],            // hyphen == space
      ['PB&J', 'PB & J', 'pb j'],                         // ampersand stripped
      ['🍕 Pizza', 'pizza!!', 'pizza'],                   // emoji/punct stripped
      ['Omega-3 (fish oil)', 'omega 3 fish oil', 'omega 3 fish oil'], // parens
    ];
    for (final c in cases) {
      test('"${c[0]}" ≡ "${c[1]}" → "${c[2]}"', () {
        expect(canonicalize(c[0]), c[2]);
        expect(canonicalize(c[1]), c[2]);
        expect(canonicalize(c[0]), canonicalize(c[1]));
      });
    }

    test('non-latin scripts (CJK) survive — letters are kept', () {
      expect(canonicalize('寿司'), '寿司');
      expect(canonicalize('jalapeño poppers'), 'jalapeño poppers');
    });

    test('tab / newline / multi-space collapse to single spaces', () {
      expect(canonicalize('  multiple   spaces\there\n'), 'multiple spaces here');
    });
  });

  group('[INV] canonicalize — structural invariants', () {
    // testTheory: invariant — properties that must hold for ALL inputs, not just
    // examples; guards against regex changes that quietly break idempotence.
    // contract: canonicalize is idempotent; canonicalTokens == split of canonical.
    // implication: storing canonical_name once and re-canonicalizing must agree.
    const inputs = [
      'PB&J', 'Café  Latte!!', '100% juice', 'Coca-Cola', '🍕 Pizza', '   ', 'x',
    ];
    test('idempotent: canonicalize(canonicalize(x)) == canonicalize(x)', () {
      for (final i in inputs) {
        expect(canonicalize(canonicalize(i)), canonicalize(i), reason: 'x="$i"');
      }
    });
    test('tokens are exactly the canonical form split on space', () {
      for (final i in inputs) {
        final c = canonicalize(i);
        final expected = c.isEmpty ? <String>{} : c.split(' ').toSet();
        expect(canonicalTokens(i), expected, reason: 'x="$i"');
      }
    });
  });

  group('[MFT] bestNameMatch — data-shape matches the nudge must catch', () {
    // testTheory: meaningful-function across realistic shapes — the nudge has to
    // rescue variants that canonicalize alone can't merge.
    // contract: token-overlap ≥ threshold surfaces a steer even when canonical differs.
    // implication: filler words / partial names still funnel to one entity.
    test('single-token name nudges to a multi-token superset (boundary 0.5)', () {
      // "eggs" shares 1/2 tokens with "scrambled eggs" → exactly 0.5 → match.
      final m = bestNameMatch('eggs', const ['Scrambled Eggs', 'Toast']);
      expect(m?.candidate, 'Scrambled Eggs');
    });

    test('filler-word variant rescued by nudge though canonical differs', () {
      // "mac & cheese" → "mac cheese"; "mac and cheese" keeps the "and" token →
      // canonical NOT equal, but token overlap 0.667 ≥ 0.5 → nudge catches it.
      expect(canonicalize('mac & cheese'), isNot(canonicalize('mac and cheese')));
      final m = bestNameMatch('mac & cheese', const ['Mac and Cheese']);
      expect(m?.candidate, 'Mac and Cheese');
    });

    test('med name with dose nudges to the bare med (dose tokens diluted)', () {
      // {vitamin,d3,2000,iu} ∩ {vitamin,d3} = 2 / union 4 = 0.5 → match.
      final m = bestNameMatch('Vitamin D3 2000 IU', const ['vitamin d3']);
      expect(m?.candidate, 'vitamin d3');
    });
  });

  group('[MFT] bestNameMatch — compound words via fuzzy-token (trigram)', () {
    // testTheory: meaningful-function — the fuzzy-token step exists to catch
    // morphological variants where whole-token equality scores 0.
    // contract: tokens ≥4 chars match by trigram overlap ≥0.4 → "burger" ≈
    //   "hamburger"; the nudge then surfaces them.
    // implication: closes the compound-word gap (burger/hamburger) probed live.
    test('single compound token nudges to its base word', () {
      expect(bestNameMatch('hamburger', const ['Burger'])?.candidate, 'Burger');
      expect(bestNameMatch('cheeseburger', const ['burger'])?.candidate, 'burger');
    });

    test('compound match survives inside a multiword name', () {
      // "hamburger" ≈ "burger" token → matches "Test-Burger" (test burger).
      expect(
        bestNameMatch('hamburger', const ['Test-Burger'])?.candidate,
        'Test-Burger',
      );
    });
  });

  group('[INV] bestNameMatch — fuzzy must NOT invent merges', () {
    // testTheory: invariant boundary — the fuzzy step's precision guards. The
    // length gate (≥4) and trigram bar (0.4) exist to keep these apart; if a
    // tuning change flips any, that is a deliberate contract change.
    // contract: short-word trigram collisions and distinct dishes stay < 0.5.
    // implication: the blame ledger isn't polluted by chips the user shouldn't see.
    test('short-word trigram collisions blocked by length gate', () {
      for (final p in const [
        ['ice', 'rice'], ['men', 'menu'], ['egg', 'eggplant'], ['art', 'start'],
      ]) {
        expect(bestNameMatch(p[0], [p[1]]), isNull, reason: '${p[0]} ~ ${p[1]}');
      }
    });

    test('distinct dishes sharing a head noun stay separate', () {
      // "sandwich" matches, but "turkey"≠"tuna" → 1/3 = 0.333 < 0.5.
      expect(bestNameMatch('turkey sandwich', const ['Tuna Sandwich']), isNull);
    });

    test('look-alike but distinct foods do not merge', () {
      expect(bestNameMatch('chicken', const ['chickpea']), isNull);
      expect(bestNameMatch('oatmeal', const ['meatball']), isNull);
    });

    test('bare generic word does not spray to a specific multiword dish', () {
      // "chicken" vs "grilled chicken breast" = 1/3 → deliberate: a generic
      // token shouldn't auto-suggest one specific dish among many.
      expect(bestNameMatch('chicken', const ['grilled chicken breast']), isNull);
    });
  });

  group('[INV] bestNameMatch — KNOWN LIMITS (pinned, not bugs)', () {
    // testTheory: invariant boundary — lexical similarity cannot equate tokens
    // that share no characters. These are deliberate non-merges; if a future
    // change (stemming, number-words, synonyms) flips them, update this contract.
    // contract: digit≠word and disjoint tokens score below threshold → no nudge.
    // implication: "2 eggs"/"two eggs" stay separate entities until we add semantics.
    test('digit form vs word form does NOT merge or nudge', () {
      expect(canonicalize('2 eggs'), isNot(canonicalize('two eggs')));
      expect(bestNameMatch('2 eggs', const ['two eggs']), isNull);
    });

    test('synonyms with no shared letters do NOT nudge (lexical, not semantic)', () {
      expect(bestNameMatch('soda', const ['Coke']), isNull);
    });
  });
}
