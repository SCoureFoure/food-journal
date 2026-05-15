"""Quick smoke test / usage example for the pattern engine.

Run this to verify the rules fire correctly before porting to Dart.

    python example_usage.py
"""

from pattern_engine import detect_references
from meal_reference_rules import RULES, TEMPORAL_KEYS, MEAL_TYPE_KEYS, build_query_spec


TEST_CASES = [
    # Should fire: yesterday + dinner
    ("I had the leftovers from dinner last night", True),
    # Should fire: same_as + breakfast
    ("same breakfast as usual", True),
    # Should fire: yesterday only (no meal type)
    ("I ate the same thing as yesterday", True),
    # Should NOT fire: plain entry with no reference
    ("chicken breast with rice and broccoli", False),
    # Should NOT fire: future tense (not a reference)
    ("I'm going to have eggs tomorrow", False),
    # Should fire: this_morning + snack
    ("just had a snack earlier", True),
    # Should fire: days_ago
    ("same thing I had a few days ago", True),
    # Should fire: named day
    ("what I had for lunch on Wednesday", True),
]


def run():
    print("=" * 60)
    print("Meal Memory Pattern Engine — Smoke Test")
    print("=" * 60)

    all_pass = True
    for text, expected_referential in TEST_CASES:
        profile = detect_references(
            text,
            RULES,
            temporal_keys=TEMPORAL_KEYS,
            meal_type_keys=MEAL_TYPE_KEYS,
        )
        passed = profile.has_temporal_ref == expected_referential
        all_pass = all_pass and passed

        status = "PASS" if passed else "FAIL"
        print(f"\n[{status}] \"{text}\"")
        print(f"  referential={profile.has_temporal_ref}  "
              f"meal_type={profile.has_meal_type}  "
              f"confidence={profile.total_confidence:.1f}")
        if profile.fired_keys:
            print(f"  fired: {profile.fired_keys}")
            spec = build_query_spec(profile)
            print(f"  query spec: {spec}")
        if not passed:
            print(f"  EXPECTED referential={expected_referential}")

    print("\n" + "=" * 60)
    print("ALL PASS" if all_pass else "SOME TESTS FAILED")
    print("=" * 60)


if __name__ == "__main__":
    run()
