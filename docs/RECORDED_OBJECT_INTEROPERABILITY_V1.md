# Recorded Object Interoperability v1

Scene:

`res://scenes/levels/prototypes/prototype_recorded_object_interoperability_lab_v1.tscn`

## Purpose

Recorded Objects now participate in elemental and physical state rather than behaving as isolated placement props. Their current position, material identity, wetness, freezing, electrical charge, combustion state, and nearby fluid volume can change what they do.

Each first-time object interaction is also reported to the progression tracker as an `object_reaction` discovery.

## Reaction matrix

### Recorded Crate

- Fire ignites it.
- Water extinguishes it and leaves it wet.
- Ice builds frozen progress. Wet crates freeze faster.
- Heavy Force shatters a fully frozen crate.
- Crates bind to shared `FluidForceVolume` water and receive buoyancy, flow, drag, wetness, and ripple feedback.
- A wet crate can conduct Lightning even though dry wood is normally a poor conductor.

### Recorded Platform

- Lightning energizes the platform for several seconds.
- The platform creates a conductive contact field while energized.
- Creatures or receivers touching the field receive a compact Lightning payload.
- Ice makes the platform brittle enough for later Force interactions.

### Recorded Spring

- Lightning grants three overcharge charges.
- Each overcharged launch is approximately 65 percent stronger.
- One charge is consumed per boosted launch.
- The energized state expires if it is not used.

### Recorded Blast Barrel

- Fire detonates a dry barrel.
- Lightning detonates a dry barrel.
- Heavy Force, combustion, and explosions retain the original detonation behavior.
- Water dampens the fuse and temporarily blocks all detonation requests.
- Barrels inside water become wet and waterlogged.
- One barrel explosion can detonate nearby dry barrels.

## Dedicated wing

The Interoperability Wing extends the original Recorded Object Proving Ground with:

- One central object interaction pad
- Fire console
- Water console
- Ice console
- Lightning console
- Force console
- A real `FluidForceVolume` buoyancy basin

The consoles apply normal `DamagePayload` objects to the nearest reproduced object. They are development fixtures, not private object-only shortcuts.

## Controls

- F1-F4: select Crate, Platform, Spring, or Blast Barrel
- F5: place the selected object on the central elemental pad
- F6: place a Crate in the water basin
- Interact: activate the nearest elemental console
- V / Y: enter or cancel free placement mode
- Q / E or L / R: cycle recorded blueprints
- R: rotate the placement preview
- Left click / A: confirm placement
- Right click / B: cancel
- F8: dismiss reproduced objects
- F9: record all blueprints
- F10: clear blueprint knowledge

## Suggested test route

1. Press F9 to record all blueprints.
2. Select Crate and press F5.
3. Apply Fire, then Water.
4. Apply Ice until the crate is visibly frozen, then apply Force.
5. Select Spring, press F5, and apply Lightning.
6. Walk onto the spring three times and compare the boosted launches.
7. Select Platform, press F5, apply Lightning, and move a receiver across its contact area.
8. Select Blast Barrel, press F5, apply Water, then Fire. It should remain inert.
9. Wait for the wet state to expire or place a fresh barrel, then apply Fire or Lightning.
10. Place two barrels close together and ignite one to test the chain reaction.
11. Press F6 and watch the crate enter, rise through, and react to the water basin.
12. Check progression notifications for object-reaction discoveries.

## Current boundaries

- Elemental behavior is available anywhere Grace reproduces these objects.
- The dedicated consoles and basin remain development fixtures.
- Conductive contact uses a small generic Lightning payload rather than joining the full circuit graph.
- Object state is scene-scoped. Blueprint knowledge and progression discoveries persist with the save slot.
- Burn, frost, electrical, fracture, and buoyancy visuals are procedural prototypes awaiting a dedicated presentation pass.

## Automated validation

`res://scenes/tests/recorded_object_interoperability_smoke_test.tscn`

Expected:

`RECORDED_OBJECT_INTEROPERABILITY_SMOKE_TEST: PASS`

The regression validates the inherited lab, all five consoles, crate combustion and extinguishing, wet freezing and Force shatter, spring overcharge, platform conductivity, barrel dampening and chain explosions, progression discovery state, and shared fluid-volume buoyancy.
