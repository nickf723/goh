# Mechanical Consumers v1 Playtest

## Goal

Confirm that repeated environmental Steam Bursts accumulate pressure and operate a physical lift through reusable consumer, reservoir, and actuator components.

## Scene

Run:

`scenes/levels/prototypes/prototype_environmental_chemistry_lab_v1.tscn`

The environmental chemistry annex is behind and left of the original elemental-reaction stations.

## Core pass

1. Enter the environmental chemistry annex.
2. Confirm the Frost Crystal freezes the central water without Grace casting Ice.
3. Stand on the right side of the lit Brazier and use a Heavy sword attack to push it into the frozen water.
4. Confirm Steam Burst triggers and the machine gauge reports roughly `32 / 100` pressure with `BURSTS: 1`.
5. Leave the Brazier close enough to the water for the automatic thaw and refreeze loop to continue.
6. Confirm the pressure slowly leaks while waiting for the next burst.
7. Repeat until the third Steam Burst crosses the `80` pressure threshold.
8. Confirm the pressure lift rises to its upper position and remains latched there.
9. Stand on the platform during a fresh run and judge whether its motion carries Grace cleanly.
10. Press F8 or use the violet reset console.
11. Confirm pressure returns to zero, burst count clears, and the platform returns to its starting height.

## Source filtering

The intake should accept only the radial `steam_burst` output.

- Merely standing near a lingering steam surface should not repeatedly charge the tank.
- Remaining inside the intake radius should not create pressure without another Steam Burst.
- The Frost Crystal and Brazier should remain ignorant of the machine. They only create environmental states and reactions.

## Readability checks

Judge whether the player can understand the chain without reading code:

`Ice source → frozen water → Fire source → Steam Burst → pressure gauge → moving lift`

Specifically inspect:

- whether the intake hood reads as the destination for steam;
- whether the gauge clearly shows progress and threshold;
- whether three cycles feels deliberate rather than tedious;
- whether leakage adds urgency without erasing progress too aggressively;
- whether the platform movement is visible, smooth, and trustworthy.

## Reset checks

After reset, verify:

- water returns to its baseline state;
- Frost Crystal and Brazier return to their initial positions and reservoirs;
- pressure is `0 / 100`;
- burst count is zero;
- lift is lowered and unlatched;
- the full machine can be completed again.

## Known prototype limitations

- The intake consumes the existing `steamed` status from `steam_burst`; it does not model fluid volume, temperature, pipe sealing, or pressure loss by distance.
- Pressure is a scalar resource rather than a simulated gas.
- The lift uses an `AnimatableBody3D` and transform-driven motion, not authored machinery animation.
- The machine latches at the top and does not consume pressure while holding its position.
- Procedural meshes and materials are replacement-ready.
