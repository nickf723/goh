# Flexible Tether Foundation v1 Playtest

## Scene

`res://scenes/levels/prototypes/prototype_flexible_tether_lab_v1.tscn`

## Purpose

Validate a shared flexible-physics substrate for environmental rope, iron chain, future chain weapons, and future whips. The first slice proves visible sag, endpoint tension, load transfer, momentum, overload failure, elemental material changes, and a counterweight pulley.

Rope and chain remain separate material and gameplay profiles while sharing the same attachment, constraint, tension, breakage, debug, and elemental-response language.

## Controls

- Move: left stick or WASD
- Camera: right stick or mouse
- Swing the chain pendulum: 1
- Add mass to the rope break test: 2
- Heat the fire-test rope: 3
- Freeze and load the frost-test rope: 4
- Swap the pulley counterweights: 5
- Toggle live tension coloring: V
- Reset the laboratory: F8 in the editor

## Expected route

1. Launch the scene.
   - Five flexible tethers and one pulley should be visible.
   - The horizontal Slack Span should settle into an unmistakable hanging curve rather than a rigid straight rod.
   - The readout should show live tension and material state.
2. Press 1 several times with a pause between presses.
   - The iron-chain pendulum should swing with persistent momentum.
   - The chain should pull taut and redden as peak tension rises.
   - The weight should remain physically coupled to its anchor.
3. Press 2 repeatedly.
   - The load-test block should gain 22 kg per press.
   - Tension should rise as gravity stretches the rope.
   - The rope should visibly break when tension exceeds its effective strength.
   - The load should fall and the readout should report `BROKEN (OVERLOAD)`.
4. Press 3 three times.
   - The rope should transition from brown toward orange-red.
   - Once ignited, burn percentage should continue climbing without more input.
   - Effective strength should fall until the rope burns through or fails under its hanging load.
5. Press 4 several times.
   - The comparison rope should become icy blue.
   - Cold raises stiffness but sharply lowers the hemp profile's break strength.
   - Each press also adds 15 kg, making brittle failure immediately visible.
6. Watch the counterweight pulley.
   - The heavier purple weight should descend while the lighter blue weight rises.
   - Both sides should remain coupled by one shared maximum length.
7. Press 5.
   - The two mass values should swap.
   - The new heavier side should reverse the pulley movement.
8. Press V.
   - Tension-based red coloring should toggle without changing the simulation.
9. Press F8.
   - The laboratory should reload into its original intact state.

## Reusable architecture

### `FlexibleMaterialProfile`

Defines shared physical and elemental properties:

- visual family: rope, chain, or filament
- linear density
- stiffness and tension damping
- failure strength
- radius and presentation
- burnability and ignition
- conductivity
- frozen stiffness and brittleness multipliers

Chain and whip weapon classes should consume profiles from this layer rather than duplicate flexible-body mathematics.

### `FlexibleTether3D`

Connects any two `Node3D` endpoints. It:

- simulates intermediate points with Verlet integration;
- solves segment-length constraints iteratively;
- applies spring-damper tension to supported endpoints;
- renders rope strands or individual chain links;
- tracks live and peak tension;
- weakens, stiffens, recolors, burns, freezes, cuts, and breaks;
- exposes debug data without requiring the laboratory.

### `PulleyTether3D`

Constrains two bodies through two pulley points and one shared length. It applies equal tension toward each pulley, allowing gravity and unequal mass to drive counterweight motion.

## Current limitations

- Tether segments do not yet collide with level geometry or wrap around arbitrary obstacles.
- Breakage opens a visual and physical gap but does not spawn persistent severed pickups.
- The pulley uses a stable shared-length force model rather than rotational wheel inertia or bearing friction.
- Heat and cold are direct laboratory inputs; production payload receivers will connect them to Fire and Ice later.
- Conductivity is material metadata only in this slice; circuit propagation through chain is deferred.
- Chain and whip weapon controllers, authored attack trajectories, hit payloads, latching, binding, grappling, and tip-speed damage are out of scope.
- Presentation is procedural prototype geometry and does not establish final weapon or dungeon art.

## Smoke test

`res://scenes/tests/flexible_tether_foundation_smoke_test.tscn`

The smoke test checks elemental profile modifiers, deterministic stretch tension and overload failure, required laboratory stations, rope and chain profile coverage, and conductive-chain metadata.
