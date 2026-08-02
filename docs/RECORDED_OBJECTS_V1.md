# Recorded Objects v1

Primary proving ground:

`res://scenes/levels/prototypes/prototype_recorded_object_lab_v1.tscn`

Field integration:

`res://scenes/levels/prototypes/prototype_ruined_village_field_progression_v1.tscn`

## Purpose

Recorded Objects are reproducible physical tools stored under Items → Objects and Journal → Blueprints. They are separate from living familiars and future multi-part engineering Builds.

Grace now receives the Recorded Object runtime automatically in gameplay scenes. The manager and compact status HUD are attached to the active Player by FullMenuDirector, so individual levels do not need to install their own copies.

The v1 loop is:

1. Study a useful physical object.
2. The blueprint enters the save-slot inventory and Journal.
3. Open Items → Objects and select the blueprint.
4. Press confirm once to prepare it.
5. Press confirm again to close the menu and begin placement.
6. Aim the translucent preview with the camera.
7. Rotate and confirm on a valid surface.
8. Spend mana and reproduce the object.

## Starter blueprints

### Recorded Crate

- Dynamic rigid body
- Costs 1 mana
- Maximum 3 active
- Can be pushed, stacked, dropped, and used as a step
- Learned naturally from the herbalist's supply crate in the Ruined Village

### Recorded Platform

- Anchored rigid body
- Costs 2 mana
- Maximum 3 active
- Provides temporary footing and short bridges
- Learned naturally from the collapsed ravine scaffold in the Ruined Village

### Recorded Spring

- Anchored launch mechanism
- Costs 2 mana
- Maximum 2 active
- Launches Grace, creatures, and rigid bodies upward
- Currently learned in the proving ground

### Recorded Blast Barrel

- Dynamic volatile object
- Costs 3 mana
- Maximum 2 active
- Detonates from Fire, Heavy force, explosions, or direct interaction
- Applies Fire damage, knockback, and an expanding blast visual
- Currently learned in the proving ground

## Production menu integration

Recorded blueprints appear under Items → Objects.

- The first confirm prepares and selects the blueprint.
- The detail panel changes to `Press A again to close the menu and begin placement.`
- The second confirm emits the placement request through FullMenuDirector.
- The menu closes, gameplay resumes, and Grace enters placement mode on the following frame.

This double-confirm prevents merely browsing an object record from unexpectedly throwing the player into gameplay.

## Gameplay HUD

Once at least one blueprint is recorded, a compact lower-right card shows:

- selected object
- mana cost
- active count and object limit
- placement validity
- invalid-placement reason
- rotation and cancel controls

The card belongs to the normal menu-suppressed HUD group. It pauses and remains hidden while the full menu is open.

## Controls

Keyboard:

- F1-F4: select blueprint in the proving ground
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
- Immediate scene-tree bounds are checked before the physics-server overlap query, preventing same-frame object overlap.
- The supporting surface is excluded from overlap checks, allowing stacking and platform placement.
- Per-blueprint and global active limits automatically dismiss the oldest matching object.

## Save and scene policy

Blueprint knowledge and current selection persist through the save slot.

Reproduced physical instances are scene-scoped. They are dismissed when the scene changes rather than serialized into save data. This avoids restoring objects into invalid geometry before world-state persistence is designed.

## Menu and Journal records

Each recorded blueprint is represented by a one-count inventory record tagged with:

- `recorded_blueprint`
- `object_blueprint`
- `summonable_object`

The inventory classifier places it under Items → Objects, while the Journal blueprint catalog exposes it under Journal → Blueprints. First-time recording also uses the progression discovery channel.

## Manual field route

1. Launch Ruined Village Field Progression.
2. Study the supply crate near the herbalist's garden.
3. Open Items → Objects.
4. Select Recorded Crate once, then confirm again.
5. Place a crate and use it as a step or movable obstacle.
6. Continue toward the ravine.
7. Study the collapsed scaffold panel on the far landing.
8. Prepare Recorded Platform from Items.
9. Rotate and place it as temporary footing.
10. Change scenes and verify the blueprints remain while placed copies do not.

## Automated validation

Core physics and catalog gate:

`res://scenes/tests/recorded_objects_v1_smoke_test.tscn`

Expected:

`RECORDED_OBJECTS_V1_SMOKE_TEST: PASS`

Production integration gate:

`res://scenes/tests/recorded_objects_production_integration_smoke_test.tscn`

Expected:

`RECORDED_OBJECTS_PRODUCTION_INTEGRATION_SMOKE_TEST: PASS`

The integration regression verifies automatic manager and HUD attachment, natural field discovery, Items preparation, double-confirm behavior, director handoff, placement activation, and production-manager reuse inside the proving ground.
