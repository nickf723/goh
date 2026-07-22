# Physical Mechanism Kit v1 Test

## Goal

Prove that a door can operate through a visible, spatially connected in-world mechanism rather than a direct scripted button-to-door command.

```text
battery -> copper cable -> pressure plate switch -> copper cable -> door motor
        <- copper cable <- movable return fuse <- copper cable <-
```

The pressure plate changes only its own conductive state. The door responds only to the motor shaft. The motor receives power only when the circuit solver finds a complete physical return path between touching terminals.

## Scene

Open:

```text
scenes/levels/prototypes/prototype_physical_mechanism_lab_v1.tscn
```

Run Current Scene.

## Test flow

1. Confirm the counterweighted door begins closed.
2. Confirm the pressure plate begins released and the circuit readout says OPEN.
3. Walk onto the pressure plate.
4. Confirm the plate visibly depresses.
5. Confirm the copper cables, battery, fuse, switch, and motor show energized glow.
6. Confirm the motor rotor spins and the door lifts upward.
7. Step off the pressure plate.
8. Confirm the circuit opens and the counterweight drives the door closed.
9. Cast Wind Gust or another force-producing action at the movable copper fuse.
10. Confirm moving the fuse away from both cable contacts breaks the circuit.
11. Stand on the pressure plate while the fuse is disconnected.
12. Confirm the door remains unpowered because the return path is physically incomplete.
13. Press F8 or use the reset console.
14. Confirm the fuse, player, plate, motor shaft, and door return to their starting states.

## Emergent test

Move the copper fuse onto the pressure plate. Because the plate accepts physical bodies rather than checking only for the player, the fuse should be capable of holding the plate down while also no longer completing the return circuit. This demonstrates that physical placement can create both useful and contradictory machine states.

## Architecture check

The laboratory controller may update labels and glow presentation, but it must not directly command the door from the pressure plate. The operational chain should remain:

```text
physical overlap -> CircuitSwitch.path_enabled
physical terminal contact -> CircuitGraph edges
closed powered path -> ElectricMotorComponent
motor current -> RotationalShaftState
shaft revolutions -> CounterweightedSlidingDoor
```

## Known limitations

- Cables are physical in placement and connectivity but do not yet have collision or flexible rope simulation.
- The door uses a counterweight backdrive approximation rather than rigid-body gears and pulleys.
- The motor limit behavior clamps the shaft at the fully open and fully closed positions.
- Lightning is not yet wired as an alternate power source in this first mechanism pass.
- Godot parser and scene validation require a local playtest.
