# Procedural Ice and Freezing v1

Run `res://scenes/levels/prototypes/prototype_ice_vfx_lab_v1.tscn`.

## Freeze Lake

1. Watch automatic replay cycle the lake from liquid to frozen and back to liquid.
2. Confirm the translucent ice sheet expands instead of appearing all at once.
3. Confirm branching freeze veins grow from the selected origin.
4. Use `ORIGIN` and confirm the generated front begins from a different quadrant.
5. Use `FREEZE` and `THAW` to drive the cycle manually.
6. Confirm the readout reports progress and the real thermal temperature.

## Crystal Garden

1. Use `GROW` several times.
2. Confirm each seeded cluster has a different but coherent arrangement.
3. Confirm crystal height and density respond to the global intensity control.
4. Inspect the generated six-sided crystal geometry in slow motion.

## Frost Wall

1. Use `FROST` and confirm branching patterns remain attached to the vertical wall plane.
2. Confirm frost dust emits outward from the wall rather than from the floor.
3. Trigger several seeds and compare the resulting fern-like networks.

## Fracture Chamber

1. Use `IMPACT` repeatedly.
2. Confirm stress increases before the slab breaks.
3. Confirm crossing the crack threshold generates procedural radial cracks.
4. Use `SHATTER` and confirm the slab disappears into generated shards and a cold flash.
5. Trigger another impact after shattering and confirm the specimen restores for another trial.

## Thaw Theater

1. Use `APPLY HEAT`.
2. Confirm the monolith contracts gradually instead of being deleted.
3. Confirm transparency changes as freeze progress recedes.
4. Confirm melt droplets appear during the thaw and a larger release appears at completion.
5. Use the control again after completion and confirm the specimen refreezes before the next thaw.

## Ice Lance Range

1. Use `LAUNCH`.
2. Confirm Ice Lance retains its original movement and payload behavior.
3. Confirm its legacy box-and-halo presentation is hidden.
4. Confirm a generated crystal body and world-space shard trail replace it.
5. Launch several projectiles and verify old trails expire cleanly.

## Global controls

- `INTENSITY` cycles Subtle, Standard, Strong, and Extreme output.
- `AUTO` pauses or resumes lake, crystal, and frost replay.
- `SLOW TIME` slows generated growth, particles, and projectile motion.
- `RESET` or `F8` restores specimens, temperature, time scale, seeds, active effects, and projectiles.

## V1 boundaries

This slice intentionally defers navigable frozen-water collision, skating friction, load-bearing ice thickness, persistent meltwater volume transfer, structural shard bodies, snow accumulation, full environmental weather, and freezing arbitrary world meshes without an authored `FreezeState` component.
