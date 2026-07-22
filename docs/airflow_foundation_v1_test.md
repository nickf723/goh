# Airflow Foundation v1 Playtest

## Scene

`res://scenes/levels/prototypes/prototype_airflow_lab_v1.tscn`

## Purpose

Validate one shared three-dimensional airflow substrate across analytic vector fields, aerodynamic drag, traversal, projectiles, temporary Gust fields, tracer advection, cloud movement, and a turbine consumer.

## Controls

- Move: left stick or WASD
- Camera: right stick or mouse
- Jump / Double Jump / Hover / Flight ascend: Jump
- Flight descend: Dodge or C
- Cast selected ability: RT or Q
- Focus spell menu: LT or mapped Focus input
- Toggle debug vectors: V
- Reset laboratory: F8 in the editor

## Expected route

1. Launch the scene and confirm cyan vector arrows and tracer particles are visible.
2. Walk into the **Directional Crosswind**.
   - The local airflow readout should show a strong positive X component.
   - Grace should drift smoothly rather than snapping sideways.
   - The 1 kg body should accelerate much more readily than the 8 kg and 36 kg bodies.
   - The turbine should rotate while it samples the same crosswind.
3. Equip **Firebolt** and fire through the crosswind.
   - The projectile should curve in the airflow direction while preserving forward momentum.
4. Equip **Gust** and cast toward props, tracers, the cloud, or the turbine.
   - Gust should appear as a moving translucent pressure structure.
   - It should register as a temporary extra vector field rather than a one-frame impulse.
   - Nearby airflow-aware systems should react to the same moving field.
5. Enter the **Updraft Shaft**.
   - Normal jumps, Hover, and Flight should gain upward motion from the field.
   - Tracers and vector arrows should point upward through the shaft.
6. Enter the **Downdraft**.
   - Jumping and Flight ascent should be opposed by downward airflow.
   - Flight controls should remain readable and correctable.
7. Enter the **Vortex**.
   - Grace, tracers, and the cloud should receive tangential, inward, and slight upward components.
   - The flow should circle around the center rather than acting as a single radial shove.
8. Toggle vectors with V and confirm the physical behavior continues when the debug visualization is hidden.
9. Press F8 and confirm Grace, props, tracers, cloud, turbine, mana, and temporary Gust fields reset.

## Mathematical contract

Each field supplies a world-space air velocity `F(x, y, z, t)`. The manager sums all active contributions at the requested position. Responsive bodies calculate aerodynamic drag from the difference between local air velocity and body velocity. Equal-area lighter bodies therefore accelerate more strongly than heavier bodies.

## Current limitations

- Analytic fields are composable gameplay vector functions, not a full computational-fluid-dynamics pressure solver.
- Solid walls do not yet occlude or redirect airflow.
- Drag uses a stable quadratic approximation with gameplay scaling and acceleration caps.
- Projectiles respond aerodynamically but do not currently expose per-element drag profiles.
- Smoke and cloud particles are lightweight visual samples rather than volumetric density cells.
- Turbine rotation is a local mechanical consumer and is not yet connected to the circuit graph.
