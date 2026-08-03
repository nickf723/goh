# Artificer Construction v1

## Purpose

Engineering is now divided into three related spell loops rather than one prefab menu:

1. `Reproduce Object` manifests one simple recorded object such as a crate, platform, spring, or blast barrel.
2. `Artificer Assembly` opens a field workshop where Grace attaches dedicated engineering parts into a personal contraption.
3. `Deploy Contraption` manifests a prepared starter schematic or personal blueprint as one functioning machine.

The four earlier Engineering Builds remain available as starter schematics, but they are now authored from the same part grammar used by player inventions.

## Spell configuration

All preparation happens while the game is paused inside the relevant spell record.

### Reproduce Object

Open:

`Magic → Reproduce Object`

Choose one simple recorded object. Casting the spell enters the existing reproduction placement mode.

### Artificer Assembly

Open:

`Magic → Artificer Assembly`

Choose:

- One prepared engineering part
- One personal blueprint slot, Contraption A through D

Casting the spell opens the field workshop. The active part can also be cycled while assembling.

### Deploy Contraption

Open:

`Magic → Deploy Contraption`

Choose one saved blueprint from:

- Starter Schematics
- Personal Contraptions

Casting the spell enters contraption deployment mode.

## Engineering part palette

### Frame Block

A heavy structural anchor used for supports, ballast, and bracing.

### Brace Beam

A long lightweight structural piece for frames, rails, axles, and improvised levers.

### Deck Plate

A broad load-bearing surface for bridges, carts, rafts, and launch decks.

### Artificer Wheel

A mobility part. Two or more wheels make a finalized contraption dynamic.

### Spring Unit

Creates a launch zone. Lightning grants three amplified launches.

### Blast Core

Creates a volatile payload. Fire, Lightning, heavy Force, or another explosion can detonate a dry core. Water dampens it.

### Float Pontoon

Adds buoyancy and fluid-flow response to the finalized machine.

### Conductor Rail

Allows Lightning to energize the contraption's contact field.

## Controller assembly controls

While `Artificer Assembly` is active:

- D-pad Up / Down: move the preview farther or nearer
- D-pad Left / Right: cycle learned engineering parts
- L / R: rotate the part by 22.5 degrees
- A: attach the part
- X: undo the most recently attached part
- Y: finalize the draft into the selected personal blueprint slot
- B: leave assembly mode

The modal control router consumes both button presses and releases. Quick items, quick spells, Focus, attacks, Divine Special, and other contextual actions do not fire beneath the workshop.

## Keyboard and mouse assembly controls

- Q / E: move preview nearer or farther
- Z / X: cycle parts
- R: rotate
- Left click: attach
- Backspace: undo
- Enter: finalize
- Right click or Escape: exit

## Draft behavior

- The first part anchors the holographic draft to the world.
- Later parts snap to a half-meter grid around the draft.
- Parts must remain close enough to connect to the existing machine.
- Overlapping parts are rejected.
- A draft requires at least two parts.
- The current prototype supports up to twelve parts.
- Building the holographic draft costs no mana.
- Finalizing saves the blueprint and optionally manifests it immediately.
- The derived contraption mana cost is paid only when a finished machine is manifested.

## Personal blueprint slots

Grace has four independent personal slots:

- Contraption A
- Contraption B
- Contraption C
- Contraption D

Finalizing replaces only the selected slot. Every slot is stored under its own save key using JSON-safe part coordinates. The earlier aggregate prototype format is migrated one slot at a time when encountered.

A saved blueprint preserves:

- Part identity
- Relative position
- Yaw rotation
- Display slot
- Save timestamp

The finalized machine is reconstructed from that exact recipe whenever it is deployed.

## Derived machine behavior

A personal contraption does not choose a prefab class. Its capabilities are derived from its parts.

- Two or more wheels make the machine dynamic.
- Spring Units create launch triggers.
- Spring Units and Conductor Rails accept Lightning.
- Float Pontoons add buoyancy and current response.
- Blast Cores add volatile detonation behavior.
- Structural parts contribute collision, mass, dimensions, and mana cost.
- Multiple Blast Cores increase blast radius, damage, and force.

The current finalized machine becomes one compound physics body. Its components preserve individual shapes and functions, but they are fused into one stable contraption when the blueprint is saved.

## Starter schematics

### Bridge Frame

Frame Blocks, Deck Plate, and Brace Beams form an anchored temporary bridge.

### Launch Tower

Frame Blocks, a Deck Plate, and a Spring Unit form a braced launch platform.

### Blast Cart

A Deck Plate, four Wheels, and a Blast Core form a mobile demolition cart.

### Conductive Raft

Two Float Pontoons, a Deck Plate, and a Conductor Rail form a buoyant energized platform.

The Engineering Build Yard stations still save these starter schematics. They now expose their part recipes and deploy through `Deploy Contraption` rather than remaining a separate conceptual system.

## Deployment controls

While `Deploy Contraption` is active:

- D-pad Up / Down: move the machine preview farther or nearer
- L / R: rotate the machine
- A: deploy
- B: cancel

The Global Context HUD reports the prepared blueprint, part count, mana cost, validity, depth, and rotation.

## Suggested playtest

1. Open `Magic → Artificer Assembly`.
2. Select Contraption A and prepare Deck Plate.
3. Assign Artificer Assembly to a quick-spell slot.
4. Cast it in the Engineering Build Yard.
5. Attach one Deck Plate.
6. Add four Wheels beneath it.
7. Add a Spring Unit on top.
8. Add a Conductor Rail.
9. Use X to undo one part and attach it again.
10. Press Y to finalize Contraption A.
11. Confirm the machine manifests and the workshop closes.
12. Apply Lightning and verify the spring receives three overcharged launches.
13. Open `Magic → Deploy Contraption`.
14. Prepare Contraption A and assign Deploy Contraption to a quick-spell slot.
15. Deploy a second copy elsewhere.
16. Save Blast Cart at its Engineering Yard station.
17. Prepare Blast Cart inside Deploy Contraption.
18. Deploy it, push it toward targets, wet it, ignite it, then repeat with a dry copy.
19. Save a different machine into Contraption B and confirm Contraption A remains unchanged.
20. Reload the scene and confirm both personal recipes persist.

## Prototype limits

- Four personal blueprint slots
- Twelve parts per personal blueprint
- Three active contraptions per scene
- Fused compound bodies after finalization
- No hinges, powered axles, fans, steering controls, rockets, ropes, or detachable joints yet
- Wheels currently determine dynamic behavior rather than simulating individual suspension and traction
- Personal blueprint renaming is reserved for a later pass

These limits keep the first version stable while preserving clear expansion points for motors, joints, control sticks, elemental engines, programmable triggers, and vehicle-scale contraptions.

## Automated validation

Scene:

`res://scenes/tests/artificer_construction_v1_smoke_test.tscn`

Expected output:

`ARTIFICER_CONSTRUCTION_V1_SMOKE_TEST: PASS`

The regression validates:

- Both Artificer spells as ability channels
- Grace-owned construction manager and modal input router
- Part cycling, depth, rotation, and HUD context
- Seven-part field assembly
- Independent personal save slot persistence
- JSON-safe coordinates
- Wheel, spring, conductor, and body-mode derivation
- Immediate manifestation
- Later redeployment
- Lightning overcharge
- Starter Blast Cart compatibility and detonation
- Continued process and physics frames
