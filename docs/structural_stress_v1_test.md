# Structural Stress and Destruction v1 Playtest

## Scene

`res://scenes/levels/prototypes/prototype_structural_stress_lab_v1.tscn`

## Purpose

Validate an authored support graph that turns weight, payload impacts, combustion, cold brittleness, and Metal Tether tension into shared structural stress. A member remains frozen only while intact connections provide a path to the world. Losing that path must immediately release the member as a normal `RigidBody3D`.

This is a stable gameplay structural model, not finite-element engineering simulation.

## Controls

- Move: left stick or WASD
- Camera: right stick or mouse
- Add scaffold load: Interact or H
- Attack the masonry joint: normal Light / Heavy weapon controls
- Select Firebolt or Metal Tether: normal Focus menu
- Cast selected spell: normal Cast control
- Reel Metal Tether: D-pad Up / Down or R / F
- Reset: F8 in the editor

## Expected route

1. Launch the scene.
   - Four stations and a compact two-line readout should appear.
   - Grace should carry the Training Hammer.
   - Firebolt and Metal Tether should be equipped through the normal spell menu.
2. Face the left **Burn Release** station and cast Firebolt into the small wooden coupling above the rope.
   - The coupling should heat and weaken.
   - Its effective capacity should fall below the hanging load.
   - The rope should visibly cut and the 36 kg box must wake and fall.
   - This is the regression test for loads remaining frozen after their rope burns.
3. At the **Redundant Scaffold**, press Interact or H once.
   - A visible 30 kg block should appear.
   - Both supports should remain intact while sharing the load.
4. Add a second 30 kg block.
   - Both supports should exceed capacity.
   - Once one fails, the other must inherit the remaining load rather than preserving the platform magically.
   - The platform and its visible added weights should fall together.
5. At **Impact Failure**, use a Heavy Hammer attack on the cracked masonry column.
   - The ordinary weapon `DamagePayload` should become structural stress through `PayloadReceiver`.
   - The column should fail from impact overload and release the lintel.
6. Open Focus, select **Metal Tether**, and aim at the gold brace above the right-hand gate.
   - Hold Cast and build tension by reeling or swinging.
   - Around 900 N, the brace should extract and the gate should fall.
7. Press F8.
   - Every assembly, connection, member, spell resource, and player state should return to its starting state through a scene reset.

## Reusable architecture

### `StructuralMaterialProfile`

Defines connection capacity, overload grace, payload-to-stress conversion, cumulative damage, fire weakening, cold brittleness, and stress colors. Wood, iron, and masonry are data profiles over the same solver.

### `StructuralIntegrity`

Receives ordinary `DamagePayload` data, sustained load, thermal state, and combustion state. It tracks live stress, effective capacity, peak stress, damage, burn weakening, brittleness, and a deterministic failure reason.

### `StructuralConnection3D`

Connects up to two structural members or a member to the authored world foundation. Failure disables its collision, cuts an optional flexible tether, rejects future Metal Tethers, and asks its assembly to recompute support.

### `StructuralAssembly3D`

Builds a graph from intact connections. World-connected members remain supported; unreachable members become live rigid bodies. Member weight is divided among its current supports, so losing one support redistributes load and can produce a cascade.

## Automated smoke test

`res://scenes/tests/structural_stress_smoke_test.tscn`

The test validates material differences, force-payload fracture, fire weakening, last-support release, redundant-load redistribution, cascading failure, required laboratory stations, the compact HUD, and Firebolt / Metal Tether loadout coverage.

## Current limitations

- Connections are authored support edges; arbitrary meshes are not automatically decomposed into structural graphs.
- Supported members remain frozen until disconnected rather than flexing continuously.
- Falling debris uses normal rigid-body collision but does not fracture into smaller generated pieces.
- Stress currently distributes by member weight and active connection count rather than beam angle, torque, or cross-section.
- Fire and Ice affect authored connections; heat propagation through an entire building is deferred.
- Metal Tether extracts one authored brace at a time.
- Prototype geometry and colors are diagnostic, not final environmental art.
