# Recorded Objects v1

Scene:

`res://scenes/levels/prototypes/prototype_recorded_object_lab_v1.tscn`

## Purpose

Recorded Objects are reproducible physical tools stored under Items → Objects and Journal → Blueprints. They are separate from living familiars and future multi-part engineering Builds.

The v1 loop is:

1. Inspect a recording station.
2. The blueprint enters the save-slot inventory and Journal.
3. Select the recorded blueprint.
4. Enter placement mode.
5. Move the translucent preview with the camera.
6. Rotate and confirm on a valid surface.
7. Spend mana and reproduce the object.

## Starter blueprints

### Recorded Crate

- Dynamic rigid body
- Costs 1 mana
- Maximum 3 active
- Can be pushed, stacked, dropped, and used as a step

### Recorded Platform

- Anchored rigid body
- Costs 2 mana
- Maximum 3 active
- Provides temporary footing and short bridges

### Recorded Spring

- Anchored launch mechanism
- Costs 2 mana
- Maximum 2 active
- Launches Grace, creatures, and rigid bodies upward

### Recorded Blast Barrel

- Dynamic volatile object
- Costs 3 mana
- Maximum 2 active
- Detonates from Fire, Heavy force, explosions, or direct interaction
- Applies Fire damage, knockback, and an expanding blast visual

## Controls

Keyboard:

- F1-F4: select blueprint
- V: enter or cancel placement mode
- Q / E: previous or next recorded blueprint
- R: rotate preview 90 degrees
- Left click: confirm placement
- Right click: cancel placement
- F8: clear reproduced objects
- F9: record all blueprints for testing
- F10: reset blueprint knowledge

Controller:

- Y: enter or cancel placement mode
- L / R: previous or next recorded blueprint while the full menu is closed
- A: confirm placement
- B: cancel placement

## Placement rules

- The target must be within the blueprint's reproduction range.
- A stable collision surface must be found under the camera target.
- The object's occupied volume must be free.
- The supporting surface is excluded from overlap checks, allowing stacking and platform placement.
- Per-blueprint and global active limits automatically dismiss the oldest matching object.

## Menu integration

Each recorded blueprint is represented by a one-count inventory record tagged with:

- `recorded_blueprint`
- `object_blueprint`
- `summonable_object`

The existing inventory classifier therefore places it under Items → Objects, while the Journal blueprint catalog exposes it under Journal → Blueprints.

## Automated validation

`res://scenes/tests/recorded_objects_v1_smoke_test.tscn`

Expected:

`RECORDED_OBJECTS_V1_SMOKE_TEST: PASS`

The regression verifies catalog integrity, inventory and Journal integration, dynamic versus anchored bodies, spring launch behavior, blast force, active-object limits, occupied-space rejection, and cleanup.
