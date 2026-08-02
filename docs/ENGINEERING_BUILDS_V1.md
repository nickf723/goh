# Engineering Builds v1

Scene:

`res://scenes/levels/prototypes/prototype_engineering_build_yard_v1.tscn`

## Purpose

Engineering Builds are saved multi-part constructions assembled from patterns Grace has already recorded. Recorded Objects remain single tools. Builds combine those patterns into larger reusable structures with their own placement cost, active limits, physical behavior, and elemental state.

Build blueprints persist in:

- Items → Builds
- Journal → Blueprints

Physical constructions remain scene-scoped.

## Assembly loop

1. Record the required component objects.
2. Inspect the matching construction station.
3. Save the composite blueprint.
4. Select the build.
5. Enter placement mode.
6. Aim and rotate the construction preview.
7. Confirm a valid location and spend mana.
8. Use elemental and physical behavior together.

Saving a build does not consume the component patterns. The prerequisite represents Grace understanding every required shape and mechanism.

## Starter builds

### Bridge Frame

Components:

- Recorded Crate
- Recorded Platform

Properties:

- Anchored construction
- 4 mana
- Maximum 2 active
- Broad elevated footing with two reproduced supports
- Intended for short gaps, raised routes, and stable combat platforms

### Launch Tower

Components:

- Recorded Crate
- Recorded Platform
- Recorded Spring

Properties:

- Anchored construction
- 6 mana
- Maximum 1 active
- Stronger base launch than the single Recorded Spring
- Lightning grants three overcharged launches
- Each overcharged launch is approximately 55 percent stronger

### Blast Cart

Components:

- Recorded Crate
- Recorded Blast Barrel

Properties:

- Dynamic construction
- 5 mana
- Maximum 2 active
- Can be pushed or knocked into position
- Fire, Lightning, Heavy Force, and nearby explosions can detonate it
- Water dampens the payload and temporarily blocks detonation
- Its blast damages and pushes nearby compatible targets

### Conductive Raft

Components:

- Recorded Crate
- Recorded Platform

Properties:

- Dynamic construction
- 6 mana
- Maximum 1 active
- Binds to shared `FluidForceVolume` water
- Receives buoyancy, flow, drag, wetness, and stability damping
- Lightning energizes the deck
- Compatible receivers touching the energized deck receive a compact Lightning payload

## Dedicated yard

The Engineering Build Yard contains:

- Four prerequisite-aware build stations
- A central quick-placement pad
- A short bridge gap
- A high launch shelf
- A demolition target cluster
- A flowing shared-water basin for the raft
- A dedicated engineering HUD

## Controls

- F1-F4: select Bridge Frame, Launch Tower, Blast Cart, or Conductive Raft
- F5: quick-place the selected construction on the central pad
- F6: deploy the Conductive Raft into the water basin
- F7: reset the testing yard while preserving blueprints
- F8: dismiss all active engineering builds
- F9: record all component objects and save all four builds
- F10: clear object and build blueprint knowledge
- V / Y: enter or cancel placement mode
- Q / E or L / R: cycle saved builds
- R: rotate the placement preview
- Left click / A: confirm placement
- Right click / B: cancel
- Interact: inspect or save a construction at a build station

## Suggested manual route

1. Start with clean blueprint knowledge.
2. Inspect the Bridge Frame station and confirm it reports its missing component patterns.
3. Record the Crate and Platform, then save the Bridge Frame.
4. Open Items → Builds and confirm the blueprint appears.
5. Open Journal → Blueprints and confirm the saved construction record appears.
6. Place the Bridge Frame across the service gap.
7. Record the Spring and save the Launch Tower.
8. Place it beneath the high shelf and test its normal launch.
9. Apply Lightning and compare the next three boosted launches.
10. Record the Blast Barrel and save the Blast Cart.
11. Push the cart toward the target cluster.
12. Apply Water, then Fire, and confirm the dampened cart remains inert.
13. Let it dry or place a fresh cart, then detonate it with Fire, Lightning, Force, or another explosion.
14. Save the Conductive Raft and press F6.
15. Observe the raft respond to the basin flow.
16. Apply Lightning and move a compatible receiver across its energized deck.
17. Place more than each build's active limit and verify the oldest copy is dismissed.
18. Try placing builds inside walls, other builds, and beyond range.

## Progression behavior

Saving a construction records a blueprint discovery. First-time systemic build interactions record `build_reaction` discoveries, including overcharged launches, raft flotation, energized contact, dampened demolition, detonation, and frozen shatter.

## Current boundaries

- The dedicated yard owns the EngineeringBuildManager for this first vertical slice.
- Production Items-to-field placement integration is reserved for the next layer after control, size, cost, and behavior playtesting.
- Build blueprints require recorded component knowledge but do not consume physical inventory.
- The first four constructions use procedural prototype geometry.
- Build state and physical copies are scene-scoped. Blueprint and discovery records persist.
- Conductive contact uses a compact generic Lightning payload rather than the full circuit graph.

## Automated validation

`res://scenes/tests/engineering_builds_v1_smoke_test.tscn`

Expected:

`ENGINEERING_BUILDS_V1_SMOKE_TEST: PASS`

The regression validates prerequisite refusal, persistent blueprint records, Items and Journal classification, bridge anchoring, Launch Tower overcharge, Conductive Raft buoyancy and energization, Blast Cart dampening and demolition, active limits, placement overlap rejection, and clean state restoration.
