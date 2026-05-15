"""Generic deterministic pattern detection engine.

Ported from magic-deck-builder/backend/engine/ (card_intent.py + intent_rules.py).
All MTG-specific logic removed. Domain rules live in meal_reference_rules.py.

Core concept:
  - Define ReferenceRules (regex patterns + a key/label)
  - Run detect_references() against any input string
  - Get back a ReferenceProfile: which rules fired, confidence scores, evidence

Confidence scoring (same as source):
  - First match for a rule: 1.0
  - Each additional match for same rule: +0.5
  - This means a string saying "last night" once scores 1.0;
    "last night's dinner that I had last night" scores 1.5.

Usage:
    from pattern_engine import detect_references
    from meal_reference_rules import RULES

    profile = detect_references("I had the leftovers from dinner last night", RULES)
    if profile.has_temporal_ref:
        # query DB, inject context, call Gemini
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Pattern


# ---------------------------------------------------------------------------
# Core dataclass
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class ReferenceRule:
    """A single detection rule: a key, a human label, and compiled regex patterns.

    Patterns are matched against normalized input text (lowercased, stripped).
    Multiple patterns per rule = any match fires the rule.
    """
    key: str
    label: str
    patterns: tuple[Pattern[str], ...]


def compile_patterns(raw: tuple[str, ...]) -> tuple[Pattern[str], ...]:
    """Compile raw regex strings into case-insensitive Pattern objects.

    Call this once at module load time — not per-request. Pre-compiled
    patterns are reused across all calls to detect_references().
    """
    return tuple(re.compile(p, flags=re.IGNORECASE) for p in raw)


# ---------------------------------------------------------------------------
# Profile dataclass
# ---------------------------------------------------------------------------

@dataclass
class ReferenceProfile:
    """Output of detect_references() for a single input string.

    Attributes:
        input_text:       The original (normalized) input.
        fired_keys:       Rules that matched, sorted by descending confidence.
        confidence:       Per-rule confidence scores. First match = 1.0, +0.5 each extra.
        evidence:         Per-rule: which pattern strings matched (up to 3).
        has_temporal_ref: True if any rule tagged as temporal fired.
        has_meal_type:    True if any rule tagged as meal_type fired.
        total_confidence: Sum of all fired rule scores. Higher = more referential.
    """
    input_text: str
    fired_keys: list[str] = field(default_factory=list)
    confidence: dict[str, float] = field(default_factory=dict)
    evidence: dict[str, list[str]] = field(default_factory=dict)
    has_temporal_ref: bool = False
    has_meal_type: bool = False
    total_confidence: float = 0.0


# ---------------------------------------------------------------------------
# Detection
# ---------------------------------------------------------------------------

def detect_references(
    text: str,
    rules: tuple[ReferenceRule, ...],
    temporal_keys: frozenset[str] | None = None,
    meal_type_keys: frozenset[str] | None = None,
) -> ReferenceProfile:
    """Run all rules against input text. Return a ReferenceProfile.

    Args:
        text:           User input string. Will be lowercased and stripped.
        rules:          Tuple of ReferenceRule objects to test (from meal_reference_rules.py).
        temporal_keys:  Rule keys to treat as temporal references for has_temporal_ref flag.
        meal_type_keys: Rule keys to treat as meal type hints for has_meal_type flag.

    Returns:
        ReferenceProfile with all fired rules, confidence scores, and convenience flags.
    """
    normalized = text.strip().lower()

    scores: dict[str, float] = {}
    evidence: dict[str, list[str]] = {}

    for rule in rules:
        rule_score = 0.0
        snippets: list[str] = []

        for pattern in rule.patterns:
            matches = pattern.findall(normalized)
            if matches:
                # First match = 1.0, subsequent matches each add 0.5.
                rule_score += 1.0 + 0.5 * (len(matches) - 1)
                snippets.append(pattern.pattern)

        if rule_score > 0:
            scores[rule.key] = rule_score
            evidence[rule.key] = snippets[:3]

    fired_keys = sorted(scores.keys(), key=lambda k: (-scores[k], k))
    total_confidence = sum(scores.values())

    has_temporal_ref = bool(
        temporal_keys and any(k in temporal_keys for k in fired_keys)
    )
    has_meal_type = bool(
        meal_type_keys and any(k in meal_type_keys for k in fired_keys)
    )

    return ReferenceProfile(
        input_text=normalized,
        fired_keys=fired_keys,
        confidence=scores,
        evidence=evidence,
        has_temporal_ref=has_temporal_ref,
        has_meal_type=has_meal_type,
        total_confidence=total_confidence,
    )


# ---------------------------------------------------------------------------
# In-process cache (optional)
# ---------------------------------------------------------------------------

_profile_cache: dict[str, ReferenceProfile] = {}


def detect_references_cached(
    text: str,
    rules: tuple[ReferenceRule, ...],
    temporal_keys: frozenset[str] | None = None,
    meal_type_keys: frozenset[str] | None = None,
) -> ReferenceProfile:
    """Cached variant — same as detect_references() but skips re-running regex
    if the same input string was already classified this session.

    Cache key is the normalized input string. Clear with clear_cache() after
    rule changes during development.
    """
    key = text.strip().lower()
    if key not in _profile_cache:
        _profile_cache[key] = detect_references(text, rules, temporal_keys, meal_type_keys)
    return _profile_cache[key]


def clear_cache() -> None:
    """Evict all cached profiles. Call after editing rules during development."""
    _profile_cache.clear()
