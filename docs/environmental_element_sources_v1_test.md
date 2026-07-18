# Environmental Element Sources v1 Playtest

## Goal

Verify that elemental reactions respond to world sources rather than requiring Grace to cast every ingredient.

The first complete chain is:

```text
Frost Crystal -> wet surface -> frozen surface
Pushable Brazier -> frozen surface -> Steam Burst
```

Neither Ice Lance nor Firebolt is required.

## Scene

Run:

```text
scenes/levels/prototypes/prototype_environmental_chemistry_lab_v1.tscn
```

The scene contains the existing Elemental Reaction Laboratory plus an environmental chemistry station in the rear-left corner.

## Automatic Ice source

1. Walk to the `ENVIRONMENT CHEMISTRY` station.
2. Observe the Frost Crystal to the left of the water.
3. Confirm the water freezes automatically after the scene begins.
4. Confirm the station readout reports:
   - `SURFACE: FROZEN`;
   - `LAST: WET_FREEZE`;
   - the Ice source as active and infinite.
5. Do not cast Ice Lance during this check.

## Pushable Fire source

1. Locate the lit Brazier on the right side of the station.
2. Stand to the right of it, facing the frozen water.
3. Use a sword strike, preferably Heavy, to push the Brazier left.
4. Confirm the Brazier moves through `ForceReceiver` rather than teleporting.
5. Push it until its fire-emission radius overlaps the frozen water.
6. Confirm the existing Steam Burst reaction triggers.
7. Confirm:
   - the surface enters `steaming`;
   - the nearby test target receives the Steam Burst consequences;
   - the Brazier receives the outward burst force when inside the radius;
   - the readout reports `LAST: STEAM_BURST`;
   - the success message identifies environmental chemistry.
8. Do not cast Firebolt during this check.

## Contact behavior

Leave the Brazier touching the water after Steam Burst.

Confirm the two sources do not repeatedly trigger a rapid freeze/steam loop. Each emitter should affect a target once per continuous contact. Separation or a laboratory reset clears that contact memory.

## Reset

Use F8 in the editor or the laboratory's violet reset console.

Confirm:

- the water returns to normal before the Frost Crystal freezes it again;
- the Brazier returns to its starting position;
- accumulated force clears;
- source contact memory clears;
- the target resets;
- the environmental station can be completed again.

## Reservoir contract

The current chemistry behavior does not consume source units merely for existing.

The source API nevertheless exposes three reservoir modes for later magic-cost work:

- `infinite`, such as an ocean;
- `renewable`, such as a spring or generator;
- `finite`, such as a torch, carried flame, battery, or contained substance.

A future spell-cost layer can request units from a nearby source. That work is intentionally not part of this pass.

## Debug contract

Inspect developer data and confirm:

- each source reports element, active state, reservoir mode, pulse count, filters, and contact memory;
- the Brazier reports position, movement speed, and force state;
- the station reports the surface, both source summaries, Brazier distance, and completion state;
- environmental payloads include `environment`, `element_source`, and their elemental tag.

## Known limitations

- Environmental influence currently uses spherical overlap volumes.
- Emitters do not yet check line of sight, insulation, containment, wind, or material permeability.
- The Brazier does not yet extinguish when its finite Fire is borrowed.
- Grace does not yet receive mana discounts or free casting from source reservoirs.
- Final VFX, audio, animation, and balance remain replacement-ready.
