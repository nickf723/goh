# Mob Engine

The Mob Engine is the shared behavioral foundation for animals, monsters, enemies, ambient wildlife, summons, and trainable familiars.

## Current layers

### Foundation

[`MOB_ENGINE_FOUNDATION_V1.md`](MOB_ENGINE_FOUNDATION_V1.md)

Defines shared moves, species body plans, move policies, continuous personality traits, utility evaluation, familiar progression, move ranks, augments, execution adapters, and the attachable brain component.

### Action lifecycle

`MobMoveExecutionState` gives every shared move a data-driven startup, active, and recovery phase. `MobBrainComponent` now begins one committed move at a time, blocks roulette-style redecision while it is active, exposes the impact window, and reports phase changes, completion, or interruption.

Live animal actors advance that shared lifecycle instead of replacing their current move every decision tick. Species-specific execution aliases such as Investigate, Follow Grace, Watch Grace, and companion commands may preserve their own duration without creating a second decision system.

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

### Bonding, consequences, and persistence

[`ANIMAL_BONDING_PERSISTENCE_V1.md`](ANIMAL_BONDING_PERSISTENCE_V1.md)

Adds stable named-animal identities, durable disk records, inventory-backed Field Treat feeding, bond requirements, Follow / Stay behavior, voluntary curious approach, wary watching, and gameplay event hooks for helping, healing, rescue, attacks, chasing, and threats.

### Navigation, rescue, and field consequences

[`WILDLIFE_NAVIGATION_RESCUE_LAB_V1.md`](WILDLIFE_NAVIGATION_RESCUE_LAB_V1.md)

Adds navigation-aware bonded movement, runtime collision-based navigation baking, dynamic rebaking after debris removal, stuck detection, conservative separation recovery, an injured rescue state, a physical Field Treat pickup, chase detection, and the real weapon damage-payload bridge.

## Relationship laboratory

Run:

`res://scenes/levels/prototypes/animal_behavior_lab_v1.tscn`

The relationship lab contains Grace, a sheep, a capybara, and a two-wolf pack.

The left on-screen panel provides mouse-clickable and controller-focusable controls for:

- Previous and next animal selection
- Peaceful or threatening Grace posture
- Feed
- Soothe
- Startle
- Make Noise
- Hunger, fear, social, curiosity, and territory debug pressure
- Clear Drives
- Reset Lab

The right bonding panel provides:

- Bond Selected
- Follow / Stay
- Help / Heal
- Report Attack
- Add 6 Treats
- Clear This Bond
- Save Bonds
- Reload Bonds

The normal restart input also resets the lab. Raw number and letter shortcuts are not required.

The selected animal is marked with a gold disc. Every animal displays its relationship, current stimulus, intention, move, trust, hunger, fear, and social need overhead.

See [`ANIMAL_BEHAVIOR_LAB_TEST.md`](ANIMAL_BEHAVIOR_LAB_TEST.md) for a guided manual test pass.

## Wildlife navigation and rescue laboratory

Run:

`res://scenes/levels/prototypes/wildlife_navigation_rescue_lab_v1.tscn`

The dedicated field lab contains:

- Juniper, an injured named sheep trapped behind debris
- A physical Field Treat basket
- A dynamically baked navigation course
- An S-shaped wall route
- A sloped lookout
- Rescue, healing, feeding, bonding, Follow / Stay, damage, repath, and separation controls
- Real weapon-payload reception through Juniper's body collision

Clear the debris, heal and feed Juniper, bond her, then lead her through the course. The panel displays navigation queries, path points, repaths, stuck time, recoveries, trust, fear, injury, and bond state.

## Validation scenes

- `res://scenes/tests/mob_engine_foundation_smoke_test.tscn`
- `res://scenes/tests/mob_drives_and_intentions_smoke_test.tscn`
- `res://scenes/tests/animal_behavior_lab_smoke_test.tscn`
- `res://scenes/tests/animal_perception_relationship_smoke_test.tscn`
- `res://scenes/tests/animal_bonding_persistence_smoke_test.tscn`
- `res://scenes/tests/wildlife_navigation_rescue_lab_smoke_test.tscn`

The live regressions verify physical Graze and Flee execution, visual and auditory perception, timed memory, trust-building interactions, wolf pack alert sharing, inventory-backed feeding, bonding, disk persistence, navigation-aware following, dynamic navmesh rebaking, rescue and healing consequences, real damage payloads, obstacle routing, and separation recovery.

## Next runtime milestone

Use the active phase to dispatch shared gameplay payloads for contact, area, projectile, support, and recovery moves; then prove the same executor across ground, swimming, flying, and burrowing body plans in an authored exploration encounter.
