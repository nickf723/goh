# Spellcasting Traditions and Achievement Ledger v0.1

## Purpose

Grace does not select a mutually exclusive magic class. She gradually masters multiple **relationships with magic** while keeping one shared spell library.

The v0.1 foundation defines two independent axes:

- **Element** describes the power a spell touches.
- **Tradition** describes how Grace reaches, prepares, or expresses that power.

A Fire spell can therefore remain one `AbilityDefinition` while being compatible with Sorcery, Wizardry, Druidry, Warlock practice, or later tradition-specific casting contexts.

## Development taxonomy

The initial development-facing traditions are:

1. Sorcery: bloodline and instinct.
2. Wizardry: study and deliberate shaping.
3. Druidry: communion with living systems and the physical world.
4. Warlock: reciprocal covenant with a patron.
5. Theurgy: devotion, protection, service, and shared conviction.
6. Bardic Magic: sound, rhythm, performance, memory, and emotion.
7. Artifice: crafted objects, devices, storage, and mechanisms.
8. Ritualism: symbols, ingredients, timing, space, and preparation.

These labels are stable IDs for development, not a final requirement for setting terminology.

## Mastery stages

Every tradition advances through the same four structural stages:

- `initiation`
- `practice`
- `trial`
- `mastery`

Stages must normally unlock in order. Each stage is represented by a cataloged achievement with an ID such as:

```text
spellcasting.warlock.initiation
spellcasting.warlock.practice
spellcasting.warlock.trial
spellcasting.warlock.mastery
```

The achievement is stored inside the existing persistent unlock ledger under a namespaced key:

```text
achievement::spellcasting.warlock.mastery
```

This reuses `GameState` save and load behavior instead of creating a second progression save format.

## Capstone hooks

Mastery exposes a data-only capstone hook. The hook does not automatically implement gameplay.

Warlock mastery reserves the approved capstone:

```text
divine_incarnation
```

That hook is the future gateway for manifesting a patron god as the active playable avatar. The other seven capstone identities remain deliberately generic until their final mechanics receive creative approval.

## Spell compatibility

`SpellcastingTraditionResolver` reads existing `AbilityDefinition` metadata:

- element;
- ability category;
- roles;
- combo, status, UI, debug, profile, delivery, and targeting tags.

Sorcery and Wizardry are baseline relationships available to every learned spell. Other traditions become compatible through element, category, or tags defined by the tradition catalog.

A spell can explicitly amend automatic resolution with metadata:

```text
tradition:artifice
tradition_block:warlock
tradition_only:ritualism
```

Underscore forms are also accepted for resources that should avoid punctuation in tags.

The resolver only reports compatibility in v0.1. It does not alter cost, cast time, payload, animation, or effects yet.

## Ownership

- `scripts/progression/spellcasting_tradition_catalog.gd`
  - canonical tradition, stage, capstone, and generated achievement definitions;
- `scripts/progression/achievement_catalog.gd`
  - known achievement definitions and validation;
- `scripts/progression/achievement_service.gd`
  - persistent namespaced achievement ledger over `GameState` unlocks;
- `scripts/progression/spellcasting_mastery_service.gd`
  - sequential progression, mastery rows, capstone readiness, debug mastery, and reset;
- `scripts/abilities/spellcasting_tradition_resolver.gd`
  - spell-to-tradition compatibility and reasoning.

## Validation

Run:

```powershell
& "C:\Users\nickf\Downloads\Godot_v4.6.2-stable_win64.exe" --headless --path . res://scenes/tests/spellcasting_mastery_smoke_test.tscn
```

Expected output:

```text
SPELLCASTING_MASTERY_SMOKE_TEST: PASS
```

The regression verifies:

- eight traditions and four ordered stages;
- 32 generated stage achievements;
- sequential progression and idempotent completion;
- persistence through the existing unlock ledger;
- Warlock mastery exposing `divine_incarnation`;
- debug mastery and clean reset;
- automatic, explicit, blocked, and exclusive spell compatibility.

## Intentionally out of scope

- platform achievements;
- mastery UI or notifications;
- player-facing unlock conditions and authored trials;
- tradition-specific cast animation, cost, targeting, or payload transformations;
- patron covenants and god relationship state;
- summoning, companion AI, avatar swapping, or Divine Incarnation runtime;
- final achievement titles and final in-world tradition names.