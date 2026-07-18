# Conductive Networks v1 Manual Test

Run:

`scenes/levels/prototypes/prototype_conductive_network_lab_v1.tscn`

## Purpose

This laboratory proves that electrical behavior comes from spatial contact and material properties rather than scripted puzzle flags.

The intended chain is:

`battery -> copper path -> physical bridge -> coil -> lamp -> switch -> return path`

The circuit-powered coil then produces a magnetic field through the existing physical interaction foundation.

## Baseline

1. The switch begins open.
2. The copper and wooden bars begin outside the gap.
3. The lamp is dark.
4. Fixed wire glow is hidden.
5. The electromagnetic coil is inactive.
6. The iron slug remains at its starting position.
7. The readout reports an open loop and zero current.

## Copper bridge

1. Push the copper bar into the upper circuit gap.
2. Align it approximately between the two exposed copper ends.
3. Leave the switch open.
4. Confirm that contact alone does not produce current while the switch breaks the loop.
5. Interact with the switch to close it.

Expected:

- The solver reports a closed loop.
- The readout reports nonzero current and total resistance.
- The complete active path glows.
- The indicator lamp turns on.
- The electromagnetic coil activates.
- The iron slug is attracted toward the energized core.

## Insulating comparison

1. Reset the laboratory.
2. Push the wooden bar into the same physical gap.
3. Close the switch.

Expected:

- The wooden bar can occupy the correct geometry.
- The circuit remains open.
- Current remains zero.
- The lamp and electromagnet remain off.

This verifies that socket occupancy is not the solution condition. Conductivity is.

## Switch behavior

With copper correctly bridging the gap:

1. Close the switch and confirm current flows.
2. Open the switch again.

Expected:

- Opening the switch immediately breaks the conductive path.
- Lamp, wire glow, and electromagnetic field deactivate.
- The iron slug stops receiving new magnetic force.

## Polarity reversal

With the copper bridge placed and the switch closed:

1. Interact with the battery.
2. Observe the battery direction label and the electromagnetic response.

Expected:

- The physical circuit remains closed.
- Current magnitude remains approximately unchanged.
- Current direction through each component reverses.
- The electromagnetic coil reverses magnetic polarity.
- Magnetic orientation or motion responds to the reversed field rather than a direct scripted command.

## Reset

Press F8 or use the reset console.

Expected:

- Copper, wood, iron, and Grace return to their initial transforms.
- The switch returns open.
- Battery polarity returns to its initial direction.
- Current and component state clear.
- Lamp and coil deactivate.
- The laboratory can be completed again.

## Creative review

Judge the following:

- Is it visually obvious where the circuit gap is?
- Is copper-versus-wood behavior understandable without reading the debug values?
- Does current illumination clearly trace the active path?
- Does closing the switch feel causally different from placing the bridge?
- Does battery reversal clearly communicate current direction and magnetic polarity?
- Is positioning the copper bar forgiving without becoming automatic?
- Does the powered coil feel like a consequence of the circuit rather than a separate switch?

## Known limitations

- V1 supports one active voltage source and one lowest-resistance closed path.
- Parallel branches, Kirchhoff nodal solving, shorts, grounding, heating, capacitance, and induction are intentionally deferred.
- Resistance values are gameplay-scale parameters rather than geometric calculations from conductor length and cross-sectional area.
- Contact is determined by terminal proximity rather than deformable plugs or cable simulation.
- Procedural meshes, materials, sound, and current-flow effects are replacement-ready.
