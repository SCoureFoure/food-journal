"""Meal memory reference rules — domain layer for pattern_engine.py.

Each ReferenceRule defines a key, a human label, and a tuple of regex patterns
that indicate the user is referencing a past meal. Add, remove, or tune rules
here without touching pattern_engine.py.

Rule keys are grouped into two sets:
  TEMPORAL_KEYS  — signals that the user is referring to a past point in time
  MEAL_TYPE_KEYS — signals which meal slot (breakfast/lunch/dinner/snack) they mean

detect_references() uses these sets to set has_temporal_ref and has_meal_type
on the returned ReferenceProfile, which drives what DB query to build.

Pattern guidelines:
  - \b word boundaries prevent "yesterday" matching "the day before yesterday" twice
  - [^.]{0,80} limits cross-sentence false positives
  - Keep patterns specific enough to avoid matching neutral food descriptions
  - Add new rules for slang your users actually say ("the usual", "my go-to")
"""

from __future__ import annotations

from pattern_engine import ReferenceRule, compile_patterns


# ---------------------------------------------------------------------------
# Temporal reference rules
# Fired when the user refers to a past point in time.
# ---------------------------------------------------------------------------

_TEMPORAL_RULES: tuple[ReferenceRule, ...] = (
    ReferenceRule(
        key="yesterday",
        label="Yesterday reference",
        patterns=compile_patterns((
            r"\byesterday\b",
            r"\blast night\b",
            r"\bthe night before\b",
        )),
    ),
    ReferenceRule(
        key="this_morning",
        label="This morning / earlier today",
        patterns=compile_patterns((
            r"\bthis morning\b",
            r"\bearlier today\b",
            r"\bearlier\b",
            r"\ba few hours ago\b",
        )),
    ),
    ReferenceRule(
        key="leftovers",
        label="Leftover reference",
        patterns=compile_patterns((
            r"\bleftovers?\b",
            r"\bthe rest of\b",
            r"\bwhat(?:'s| was) left\b",
        )),
    ),
    ReferenceRule(
        key="same_as_before",
        label="Same as a prior entry",
        patterns=compile_patterns((
            r"\bsame [^.]{0,30}as\b",  # "same X as", "same thing as"
            r"\bsame thing\b",
            r"\bagain\b",
            r"\b(?:the |my |as )?usual\b",  # "the usual", "my usual", "as usual", "usual"
            r"\bmy go.?to\b",
            r"\bwhat i (?:always|usually|normally) (?:have|eat|get)\b",
        )),
    ),
    ReferenceRule(
        key="days_ago",
        label="N days ago",
        patterns=compile_patterns((
            r"\b(?:a )?(?:few|couple(?:\s+of)?) days ago\b",
            r"\b(?:two|three|four|five|2|3|4|5) days ago\b",
            r"\bearlier this week\b",
        )),
    ),
    ReferenceRule(
        key="named_day",
        label="Named weekday reference",
        patterns=compile_patterns((
            r"\b(?:on\s+)?(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b",
            r"\bthe other day\b",
        )),
    ),
)

# ---------------------------------------------------------------------------
# Meal type rules
# Fired when the user names a meal slot — helps narrow the DB query.
# ---------------------------------------------------------------------------

_MEAL_TYPE_RULES: tuple[ReferenceRule, ...] = (
    ReferenceRule(
        key="meal_breakfast",
        label="Breakfast slot",
        patterns=compile_patterns((
            r"\bbreakfast\b",
            r"\bmorning meal\b",
            r"\bbrunch\b",
        )),
    ),
    ReferenceRule(
        key="meal_lunch",
        label="Lunch slot",
        patterns=compile_patterns((
            r"\blunch\b",
            r"\bmidday\b",
            r"\bnoon\b",
        )),
    ),
    ReferenceRule(
        key="meal_dinner",
        label="Dinner slot",
        patterns=compile_patterns((
            r"\bdinner\b",
            r"\bsupper\b",
            r"\bevening meal\b",
        )),
    ),
    ReferenceRule(
        key="meal_snack",
        label="Snack",
        patterns=compile_patterns((
            r"\bsnack\b",
            r"\ba bite\b",
            r"\ba little something\b",
        )),
    ),
)

# ---------------------------------------------------------------------------
# Combined rule set and key sets
# ---------------------------------------------------------------------------

RULES: tuple[ReferenceRule, ...] = _TEMPORAL_RULES + _MEAL_TYPE_RULES

TEMPORAL_KEYS: frozenset[str] = frozenset(r.key for r in _TEMPORAL_RULES)
MEAL_TYPE_KEYS: frozenset[str] = frozenset(r.key for r in _MEAL_TYPE_RULES)


# ---------------------------------------------------------------------------
# Convenience: build a DB query spec from a ReferenceProfile
# ---------------------------------------------------------------------------

from pattern_engine import ReferenceProfile  # noqa: E402 — post-class import ok


def build_query_spec(profile: ReferenceProfile) -> dict:
    """Translate a ReferenceProfile into a structured DB query spec.

    Returns a dict the caller can use to query the meal_fingerprints table.
    The caller decides how to execute the query (SQLite, Drift, etc.).

    Shape:
        {
          "date_offset": int | None,   # 0 = today, 1 = yesterday, None = unknown
          "meal_type": str | None,     # "breakfast" | "lunch" | "dinner" | "snack" | None
          "is_leftover": bool,         # True → same meal, different entry
          "match_recent": bool,        # True → just get the N most recent entries
        }
    """
    spec: dict = {
        "date_offset": None,
        "meal_type": None,
        "is_leftover": False,
        "match_recent": False,
    }

    fired = set(profile.fired_keys)

    # Date offset
    if "yesterday" in fired or "leftovers" in fired:
        spec["date_offset"] = 1          # yesterday
    elif "this_morning" in fired:
        spec["date_offset"] = 0          # today (earlier slot)
    elif "days_ago" in fired:
        spec["date_offset"] = 3          # rough midpoint; caller can refine
    elif "same_as_before" in fired or "named_day" in fired:
        spec["match_recent"] = True

    # Meal type
    for key, meal_type in (
        ("meal_breakfast", "breakfast"),
        ("meal_lunch", "lunch"),
        ("meal_dinner", "dinner"),
        ("meal_snack", "snack"),
    ):
        if key in fired:
            spec["meal_type"] = meal_type
            break

    # Leftover flag
    if "leftovers" in fired or "same_as_before" in fired:
        spec["is_leftover"] = True

    return spec
