# Mob Engine

The Mob Engine is the shared behavioral foundation for animals, monsters, enemies, ambient wildlife, summons, and trainable familiars.

## Current layers

### Foundation

[`MOB_ENGINE_FOUNDATION_V1.md`](MOB_ENGINE_FOUNDATION_V1.md)

Defines shared moves, species body plans, move policies, continuous personality traits, utility evaluation, familiar progression, move ranks, augments, execution adapters, and the attachable brain component.

### Action lifecycle

`MobMoveExecutionState` gives every shared move a data-driven startup, active, and recovery phase. `MobBrainComponent` now begins one committed move at a time, blocks roulette-style redecision while it is active, exposes the impact window, and reports phase changes, completion, or interruption.

Live animal actors advance that shared lifecycle instead of replacing their current move every decision tick. Species-specific execution aliases such as Investigate, Follow Grace, Watch Grace, and companion commands may preserve their own duration without creating a second decision system.

The first crossing into the active phase now claims exactly one normalized effect request. Startup interruption prevents the request, staying in the active phase cannot duplicate it, and coarse frames still preserve the crossing before completion.

### Body, locomotion, and effect delivery

[`ANIMAL_BODY_LOCOMOTION_AND_EFFECTS_V1.md`](ANIMAL_BODY_LOCOMOTION_AND_EFFECTS_V1.md)

Adds validated ground, swimming, flight, climbing, burrowing, runner, jumper, serpentine, and hover capabilities. Species body tags determine which modes resolve, while aliases let authored data migrate toward the canonical vocabulary. The shared runtime executes legal mode transitions, medium checks, planar/surface/volumetric steering, water currents, buoyancy, gravity policy, and opt-in gait modifiers. `GenericAnimalActor` exposes its active mode to move policy and uses both the existing `SwimmingWaterVolume` hook and the new generic `MobTraversalMedium`. Traversal media supply environmental tags, surface normals, adhesion velocity, and waypoint guidance without species code. The canonical lab proves these contracts with Trout, Goose, Gecko, Mole, and amphibious Capybara actors.

`MobMoveEffectRequest` separates effect timing from physical targeting. `MobEffectTargetResolver` provides authoritative actor-owned targeting with optional generic fallbacks and relation filters. `MobMoveEffectExecutor` handles exactly-once contact, area, projectile, recovery, and custom/executor dispatch. Projectile actions reuse the physical `GenericProjectile`; `MobPayloadBridge` keeps consequences inside the existing `DamagePayload → PayloadReceiver` grammar.

`MobVitalsComponent` derives health from species base stats and supplies shared health, stamina, recovery, reset, and incapacitation behavior. Generic animals compose the existing combat `StatusReceiver`; its active statuses now enter policy evaluation, and damage-over-time ticks can use the shared actor payload method when no `HitReceiver` child exists.

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
- Contact, area, projectile, and recovery effect execution
- Species-derived health, stamina, injury-aware decisions, and incapacitation
- Timed buffs, damage-over-time, control states, and movement modifiers available to move policies
- Reusable procedural quadruped, waterfowl, fish, low-reptile, and digging-mammal prototype bodies
- Overhead intention, move, health, and drive readouts

### Perception, memory, and relationships

[`ANIMAL_PERCEPTION_RELATIONSHIPS_V1.md`](ANIMAL_PERCEPTION_RELATIONSHIPS_V1.md)

Adds species-shaped sight cones, hearing, physics line of sight, timed last-known-position memory, same-species alert sharing, persistent trust and fear associations toward Grace, peaceful habituation, and Feed, Soothe, and Startle interactions.

### Bonding, consequences, and persistence

[`ANIMAL_BONDING_PERSISTENCE_V1.md`](ANIMAL_BONDING_PERSISTENCE_V1.md)

Adds stable named-animal identities, durable disk records, inventory-backed Field Treat feeding, bond requirements, Follow / Stay behavior, voluntary curious approach, wary watching, and gameplay event hooks for helping, healing, rescue, attacks, chasing, and threats.

### Navigation, rescue, and field consequences

[`WILDLIFE_NAVIGATION_RESCUE_LAB_V1.md`](WILDLIFE_NAVIGATION_RESCUE_LAB_V1.md)

Adds navigation-aware bonded movement, runtime collision-based navigation baking, dynamic rebaking after debris removal, stuck detection, conservative separation recovery, an injured rescue state, a physical Field Treat pickup, chase detection, and the real weapon damage-payload bridge.

## Animal behavior and relationship laboratory

Run:

`res://scenes/levels/prototypes/animal_behavior_lab_v1.tscn`

The lab contains Grace, Mallow the Sheep, Bramble the Capybara, the Ash/Cinder wolf pack, Juniper the Goose, Ripple the Trout, Mica the Gecko, and Loam the Mole. Its reusable habitats are a real pond, an adhesive collision wall with a surface route, and a three-dimensional translucent soil route.

The left on-screen panel provides mouse-clickable and controller-focusable controls for:

- Previous and next animal selection
- Place compatible selected animals in the pond
- Launch or land the Goose through the shared locomotion executor
- Place compatible selected animals on the climb wall
- Place compatible selected animals in the burrow route
- Return the selected animal to its authored start and restart its habitat route
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

The selected animal is marked with a gold disc. Every animal displays its relationship, current stimulus, intention, move, locomotion mode, trust, hunger, fear, and social need overhead. The selected-animal panel also reports height for flight and water testing.

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

The live regressions verify locomotion capability validation, runtime ground/swimming/flight/climbing/burrowing transitions including direct air-water transitions, medium rejection, planar/surface/volumetric steering, water-current sampling, surface buoyancy, surface adhesion, waypoint guidance, gravity handoff, opt-in modifier dependencies, generic water and traversal-medium integration, authored Goose, Trout, Gecko, and Mole bodies, canonical habitat controls, incompatible-mode rejection, physical route progress, and reset modes, species-derived vitals, damage and recovery, incapacitation, timed status refresh and expiry, policy-visible condition tags, exactly-once contact and area delivery, authoritative target ownership, physical projectile spawning and reset cleanup, physical Graze and Flee execution, visual and auditory perception, timed memory, trust-building interactions, wolf pack alert sharing, inventory-backed feeding, bonding, disk persistence, navigation-aware following, dynamic navmesh rebaking, rescue and healing consequences, real damage payloads, obstacle routing, and separation recovery.

## Next runtime milestone

The shared runtime and generic actor now execute ground, swimming, flight, surface climbing, and routed burrowing without a species-specific brain. Juniper, Ripple, Mica, Loam, and Bramble make those contracts playable with the same moves, drives, vitals, relationships, bonding, and reset path. Next, reuse `MobTraversalMedium` in existing exploration content; let that authored application determine whether ceiling/corner orientation, hidden tunnel presentation, entrances/exits, or terrain deformation is needed before expanding broader habitat and ecology behavior.
