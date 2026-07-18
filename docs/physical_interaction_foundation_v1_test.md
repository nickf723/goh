# Physical Interaction Foundation v1 QA

## Goal

Verify that the project now has a shared physical substrate for material properties, spatial vector fields, continuous force, torque, and inspectable material-specific responses.

This slice is deliberately smaller than the future electricity and magnetism engine. It proves the reusable foundation before adding circuit graphs, induction, coils, polarization tools, or charged-particle behavior.

## Scene

Run:

```text
scenes/levels/prototypes/prototype_physical_interaction_lab_v1.tscn
```

The chamber contains:

- one energized magnetic dipole core;
- one reversible-polarity switch;
- one permanent magnet bar;
- one ferromagnetic iron slug;
- one highly conductive but effectively nonmagnetic copper block;
- one live field, force, torque, and magnetization readout;
- one reset console.

## Manual pass

### Permanent magnet torque

1. Observe the red-and-blue permanent magnet bar at the rear of the core.
2. Confirm it begins visibly misaligned with the field.
3. Confirm it rotates rather than merely translating.
4. Interact with the violet polarity switch.
5. Confirm the switch label reverses.
6. Confirm the magnet receives new torque and turns toward the opposite field alignment.

The rotation may include some physical settling. It should not teleport directly to a solved angle.

### Iron attraction

1. Observe the iron slug to the right of the core.
2. Confirm it gains induced magnetization in the live readout.
3. Confirm it moves toward the stronger field near the core.
4. Reverse polarity.
5. Confirm iron remains attracted because its induced magnetization follows the field rather than acting as a fixed permanent pole.

### Copper comparison

1. Observe the copper block to the left of the core.
2. Confirm the label identifies it as conductive but nonmagnetic.
3. Confirm it remains essentially stationary while iron moves.
4. Confirm the readout reports negligible magnetic force for copper.

This distinction is critical: electrical conductivity must not imply ferromagnetism.

### Reset

1. Allow the magnet and iron to move.
2. Reverse polarity.
3. Press F8 or interact with the reset console.
4. Confirm all three specimen bodies return to their initial transforms.
5. Confirm stored impulse velocity, continuous velocity, angular velocity, force sources, torque sources, and induced magnetization clear.
6. Confirm polarity returns to its initial direction.

## Debug contract

The debug data should expose:

- physical material identity and normalized coefficients;
- sampled field vector, strength, source, and distance;
- active continuous force and torque sources;
- integrated linear and angular velocity;
- induced magnetization;
- current field polarity and sample count.

## Automated validation

The registered smoke test verifies:

1. Copper is highly conductive but below the magnetic-response threshold.
2. Iron is strongly magnetically responsive.
3. The permanent magnet exposes a permanent magnetic moment.
4. Reversing polarity reverses the sampled field vector.
5. Equal force accelerates a lighter body more than a heavier body.
6. Continuous torque produces angular velocity.
7. A misaligned permanent magnet receives torque.
8. Iron receives attraction toward the field gradient.
9. Iron's response greatly exceeds copper's response.

## Creative review

Judge:

- whether the field feels physical rather than scripted;
- whether torque is visually distinct from attraction;
- whether polarity reversal creates a readable change;
- whether the iron-versus-copper comparison is immediately understandable;
- whether motion remains stable enough to become puzzle infrastructure;
- whether the live values clarify the system without replacing the physical demonstration.

## Explicitly out of scope

- circuit graph solving;
- voltage, current, resistance, shorts, and grounding;
- electromagnets powered by an actual circuit;
- induced current from changing magnetic flux;
- eddy currents and copper magnetic braking;
- charged particles and electric-field forces;
- final field-line VFX or production materials;
- retrofitting every existing physical prop.

Those systems should build on this foundation in later vertical slices.
