# Mob Engine

The Mob Engine is the shared behavioral foundation for animals, monsters, enemies, ambient wildlife, summons, and trainable familiars.

## Current layers

### Foundation

[`MOB_ENGINE_FOUNDATION_V1.md`](MOB_ENGINE_FOUNDATION_V1.md)

Defines shared moves, species body plans, move policies, continuous personality traits, utility evaluation, familiar progression, move ranks, augments, execution adapters, and the attachable brain component.

### Drives and intentions

[`MOB_DRIVES_AND_INTENTIONS_V1.md`](MOB_DRIVES_AND_INTENTIONS_V1.md)

Adds persistent hunger, fatigue, fear, social need, curiosity, and territorial pressure; generic score-modifier channels; drive satisfaction; and commitment to behavioral intentions across decision ticks.

## Validation scenes

- `res://scenes/tests/mob_engine_foundation_smoke_test.tscn`
- `res://scenes/tests/mob_drives_and_intentions_smoke_test.tscn`

## Next runtime milestone

Build a generic animal actor and execution adapter capable of performing the shared ambient, movement, forage, flee, social, and contact-attack vocabulary selected by `MobBrainComponent`.
