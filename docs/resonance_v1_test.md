# Resonance and Material Frequency v1

## Purpose

Validate that Sound delivers frequency and energy rather than generic damage, and that reusable resonant bodies independently decide whether to vibrate, transfer energy, activate machinery, or fracture.

## Launch

Run:

`res://scenes/levels/prototypes/prototype_resonance_lab_v1.tscn`

The laboratory is also available from the Development Control Center as **Resonance Laboratory**.

## Controls

- **Move / Camera:** normal traversal controls.
- **Interact:** cycle Resonant Pulse through 110, 220, 440, and 660 Hz.
- **Cast:** emit the currently tuned Resonant Pulse.
- **Reset:** restore all resonators, glass, and machinery.

## Manual route

1. Begin at 220 Hz and use **Cast** near the four-column Selective Resonance gallery.
2. Confirm the 220 Hz column vibrates much more strongly than the 110, 440, and 660 Hz columns.
3. Use **Interact** and repeat at every available frequency. The matching column should change each time.
4. Return to 220 Hz and stand on the blue marker beside the Sympathetic Vibration station.
5. Use **Cast** near the Primary fork.
6. Confirm the farther Coupled fork gains energy and visibly vibrates even when it is beyond the pulse edge.
7. Tune to 440 Hz and approach the Resonant Lock.
8. Cast repeatedly without waiting too long. Matching energy should accumulate until the gate rises.
9. Tune to 660 Hz and stand near the glass marker.
10. Cast into the suspended glass cluster. The five frozen shards should fracture, become physical rigid bodies, and burst apart.
11. Observe the compact HUD. It should report active frequency, hottest resonator, coupled-fork energy, gate state, and fracture count.
12. Use **Reset** and confirm the gate, resonators, and five glass shards return to their initial state.

## Automated contract

Run:

`res://scenes/tests/resonance_smoke_test.tscn`

The test verifies:

- exact-frequency response and detuning rejection;
- energy accumulation and damping;
- activation and fracture thresholds;
- sympathetic coupling between matched resonators;
- Resonant Pulse delivery through `ResonancePayload`;
- laboratory fixtures, loadout, and compact telemetry.

## Intentional limitations

- Frequency bands are gameplay-scaled rather than acoustic-material measurements.
- Sound propagation uses radial distance without wall occlusion, reflection, diffraction, or room acoustics.
- Resonators expose authored natural frequencies rather than deriving them from mesh geometry and material dimensions.
- Sympathetic transfer is local energy coupling, not a full wave equation.
- Final audio synthesis, controller rumble, and production animation are deferred.

