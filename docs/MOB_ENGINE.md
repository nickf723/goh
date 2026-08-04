# Mob Engine

The Mob Engine is the shared behavioral foundation for animals, monsters, enemies, ambient wildlife, summons, and trainable familiars.

## Current layers

### Foundation

[`MOB_ENGINE_FOUNDATION_V1.md`](MOB_ENGINE_FOUNDATION_V1.md)

Defines shared moves, species body plans, move policies, continuous personality traits, utility evaluation, familiar progression, move ranks, augments, execution adapters, and the attachable brain component.

### Drives and intentions

[`MOB_DRIVES_AND_INTENTIONS_V1.md`](MOB_DRIVES_AND_INTENTIONS_V1.md)

Adds persistent hunger, fatigue, fear, social need, curiosity, and territorial pressure; generic score-modifier channels; drive satisfaction; and commitment to behavioral intentions across decision ticks.

### Live animal actor

`GenericAnimalActor` turns selected Mob Engine moves into visible prototype behavior using a reusable `CharacterBody3D` actor.

The first executor supports:

- Ambient wandering
- Grazing and forage-seeking
- Habitat and water-seeking
- Flee and backstep movement
- Pack howling
- Contact attack and pounce movement
- Procedural sheep, capybara, and wolf silhouettes
- Overhead intention, move, and drive readouts

### Perception, memory, and relationships

[`ANIMAL_PERCEPTION_RELATIONSHIPS_V1.md`](ANIMAL_PERCEPTION_RELATIONSHIPS_V1.md)

Adds species-shaped sight cones, hearing, physics line of sight, timed last-known-position memory, same-species alert sharing, persistent trust and fear associations toward Grace, peaceful habituation, and Feed, Soothe, and Startle interactions.

## Playable test scene

Run:

`res://scenes/levels/prototypes/animal_behavior_lab_v1.tscn`

The lab contains Grace, a sheep, a capybara, and a two-wolf pack.

The on-screen panel provides mouse-clickable and controller-focusable controls for:

- Previous and next animal selection
- Peaceful or threatening Grace posture
- Feed
- Soothe
- Startle
- Make Noise
- Hunger, fear, social, curiosity, and territory debug pressure
- Clear Drives
- Reset Lab

The normal restart input also resets the lab. Raw number and letter shortcuts are no longer required.

The selected animal is marked with a gold disc. Every animal displays its relationship, current stimulus, intention, move, trust, hunger, fear, and social need overhead.

See [`ANIMAL_BEHAVIOR_LAB_TEST.md`](ANIMAL_BEHAVIOR_LAB_TEST.md) for a guided manual test pass.

## Validation scenes

- `res://scenes/tests/mob_engine_foundation_smoke_test.tscn`
- `res://scenes/tests/mob_drives_and_intentions_smoke_test.tscn`
- `res://scenes/tests/animal_behavior_lab_smoke_test.tscn`
- `res://scenes/tests/animal_perception_relationship_smoke_test.tscn`

The live regressions verify physical Graze and Flee execution, on-screen lab controls, visual and auditory perception, timed memory, trust-building interactions, startle fear, and wolf pack alert sharing.

## Next runtime milestone

Connect relationships to persistent named animals and gameplay events, then improve execution fidelity with navigation-aware destinations, action completion callbacks, interrupted actions, attack hit confirmation, and richer herd or pack coordination.
