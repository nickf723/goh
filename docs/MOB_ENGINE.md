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

## Playable test scene

Run:

`res://scenes/levels/prototypes/animal_behavior_lab_v1.tscn`

The lab contains Grace, a sheep, a capybara, and a two-wolf pack.

Controls:

- `1`-`4` or `Tab`: select an animal
- `P`: toggle whether the animals perceive Grace as a threat
- `H`: maximize hunger
- `F`: maximize fear
- `J`: maximize social need
- `K`: maximize curiosity
- `T`: maximize territorial pressure
- `C`: clear the selected animal's drive pressure
- The configured restart input resets the lab

The selected animal is marked with a gold disc. Every animal displays its current intention, selected move, hunger, fear, and social need overhead.

See [`ANIMAL_BEHAVIOR_LAB_TEST.md`](ANIMAL_BEHAVIOR_LAB_TEST.md) for a guided manual test pass.

## Validation scenes

- `res://scenes/tests/mob_engine_foundation_smoke_test.tscn`
- `res://scenes/tests/mob_drives_and_intentions_smoke_test.tscn`
- `res://scenes/tests/animal_behavior_lab_smoke_test.tscn`

The live regression verifies that a hungry safe sheep selects Graze, a frightened sheep selects Flee, and the Flee executor physically increases its distance from a live threat.

## Next runtime milestone

Improve execution fidelity with navigation-aware destinations, action completion callbacks, interrupted actions, attack hit confirmation, and small herd or pack coordination behaviors.
