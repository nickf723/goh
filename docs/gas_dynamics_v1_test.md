# Reactive Gas Dynamics v1 Playtest

## Scene

`res://scenes/levels/prototypes/prototype_gas_dynamics_lab_v1.tscn`

## Purpose

Validate a reusable atmospheric density system in which Smoke and Poison Gas occupy coarse three-dimensional scalar grids, retain state over time, move through the existing analytic Airflow vector fields, diffuse, decay, rise or settle through gas-specific buoyancy, and affect Grace according to the density sampled at her position.

This pass also validates that the same behavior remains readable under a practical CPU budget. The first laboratory build ran near 15 FPS on Nick's machine, so v1 now uses active-region simulation, staggered grid updates, coarser cells, decimated debug rendering, cached cell positions, and a registered Airflow field cache.

## Controls

- Move: left stick or WASD
- Camera: right stick or mouse
- Jump / Double Jump / Hover / Flight ascend: Jump
- Flight descend: Dodge or C
- Cast selected ability: RT or Q
- Focus spell menu: LT or mapped Focus input
- Toggle airflow vectors: V
- Toggle gas-density voxels: B
- Reset laboratory: F8 in the editor

The laboratory equips **Gust** first and **Flight** second.

## Expected route

1. Launch the scene.
   - Gray Smoke density voxels should begin forming above the left emitter.
   - Green Poison density voxels should begin forming close to the right-side floor.
   - Cyan vector arrows should show the transport fields independently of the gas visualization.
   - The local readout should include the number of Smoke and Poison cells simulated during the latest steps.
2. Observe the **Smoke Chimney**.
   - Smoke should rise from its emitter through both its own positive buoyancy and the authored updraft.
   - The Base, Mid, and Crown sensors should report different densities as the plume develops.
   - Smoke should be carried toward the rear Vortex Transport region rather than remaining a fixed sphere.
3. Walk into the Smoke plume.
   - The local readout should report Smoke density and an accumulating Smoke dose.
   - Sustained exposure should add a subtle screen obscuration.
   - Leaving the plume should reduce the dose and clear the obscuration.
4. Observe the **Poison Basin**.
   - Poison Gas should remain concentrated near the floor because its profile has downward buoyancy.
   - The Poison Low sensor should generally read more density than the elevated Poison High sensor.
   - The authored crosswind should transport the cloud laterally.
5. Walk through Poison Gas briefly.
   - Local Poison density and dose should rise.
   - Once the effective-dose threshold is crossed, Grace should take one damage per exposure interval.
   - Leaving the cloud should allow the dose to decay and stop further damage.
6. Equip **Gust** and cast through either cloud.
   - Gust should create a moving temporary Airflow vector field.
   - Gas density should be relocated through the same advection sampler used by permanent fields.
   - Sensors and local exposure should respond to the new distribution rather than to a fixed trigger volume.
7. Observe the **Vortex Transport** region.
   - Smoke entering the region should receive tangential, inward, and slight upward transport.
   - The plume should curl around the vortex rather than receiving a single radial impulse.
8. Press V.
   - Vector arrows should hide while Gas simulation continues.
   - Hidden vectors should stop rebuilding their debug mesh.
9. Press B.
   - Density voxels should hide while sensors, exposure, and simulation continue.
   - Hidden density voxels should stop receiving visual-transform updates.
10. Press F8.
    - Smoke and Poison density clear.
    - Emitters restart.
    - Temporary Gust fields disappear.
    - Grace, health, mana, exposure doses, and screen obscuration return to the opening state.

## Performance contract

- Smoke uses a `14 × 8 × 14` grid with 1.2-meter cells, for 1,568 possible cells.
- Poison uses a `12 × 6 × 10` grid with 1.15-meter cells, for 720 possible cells.
- Both grids update at approximately 5.6 simulation steps per second and cap catch-up work at one step per rendered frame.
- Poison begins half a simulation interval after Smoke so the two expensive steps do not normally land on the same frame.
- Each grid simulates only the occupied density bounds plus a three-cell transport margin and active emitters.
- Density debug meshes sample every second cell on each axis and refresh independently at a slower rate.
- Static and temporary Airflow fields register once with `AirflowManager`; density cells no longer rebuild the scene-tree field list for every sample.
- Cell local and world positions are cached until the Gas grid's transform changes.

The simulated-cell readout should usually remain well below the full 2,288-cell laboratory capacity while the plumes are localized. It may rise as density spreads across more of either grid.

## Mathematical contract

Each Gas volume stores a scalar density field `D(x, y, z, t)` on a local voxel grid. For each active simulation cell, the solver traces backward through the combined Airflow velocity and the Gas profile's buoyancy velocity, samples the previous density trilinearly, blends neighboring density for diffusion, applies exponential decay, and then receives matching emitter injection.

Gas exposure is not based on touching an `Area3D`. A receiver samples local density, integrates a dose over time, and applies effects only after the configured effective-dose threshold is reached.

## Current limitations

- The simulation is a coarse, stable gameplay field rather than a full pressure-based computational-fluid-dynamics solver.
- Solid geometry does not yet block, redirect, or seal Gas flow.
- Gas grids have authored finite bounds; density leaving those bounds is lost.
- Very faint density below the active-region threshold is deliberately discarded as a performance tradeoff.
- Smoke obscuration is a simple full-screen concentration overlay rather than a volumetric camera renderer.
- Poison exposure currently damages Grace directly in this laboratory; broader actor resistance and filtration equipment are deferred.
- Combustible Gas ignition, Steam condensation, weather-scale Smog, enemy perception, and circuit-driven ventilation are intentionally deferred.
