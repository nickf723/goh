# Soul Circuit Puzzle v1 Manual Test

## Scene

```txt
res://scenes/levels/prototypes/prototype_soul_circuit_puzzle_v1.tscn
```

## Purpose

Validate that Soul Grip, physical occlusion, mass-sensitive manipulation, pressure switching, movable circuit topology, motor output, counterweight return, and breakable pickup rewards form one readable puzzle rather than disconnected laboratory demonstrations.

## Controller controls

```txt
MOVE                 Left stick
AIM                  Right stick
SOUL GRIP            Hold LB
DISTANCE              D-pad Up / Down
ROTATE                D-pad Left / Right
CAST                  RT
LIGHT                 X
HEAVY                 RB
RESET                 F8 in this development scene
```

## Intended route

1. Approach the sealed left alcove.
2. Confirm that the copper fuse cannot be selected through the giant stone slab.
3. Hold Soul Grip and move the slab clear of the alcove entrance.
4. Recover the copper fuse from the alcove.
5. Pull the stone weight down from the raised shelf.
6. Leave the stone weight on the pressure plate.
7. Rotate and place the copper fuse across the marked return gap.
8. Confirm that the complete physical circuit powers the motor and raises the gate.
9. Pass through the gate and break the supply crate.
10. Press F8 and confirm that the player, slab, weight, fuse, circuit, door, and reward crate return to their starting states.

## Expected physical behavior

- The giant slab blocks movement, sight, and Soul Grip acquisition until moved.
- The slab remains collision-bound while manipulated and feels slower than the fuse.
- The pressure plate closes only while Grace or another physics body rests on it.
- The fuse must place both of its terminals within contact range of the two return cables.
- The pressure plate never calls the door directly.
- The circuit solver energizes the motor only when the source, switch, cables, fuse, and motor form a complete loop.
- Removing the weight or fuse opens the circuit and lets the counterweight close the door.
- The supply crate drops ordinary reusable resource pickups.

## Useful alternate solutions

- Grace may stand on the plate while manipulating the fuse, then attempt to race through before the counterweight closes the gate.
- The giant slab may be moved into inconvenient positions and can physically obstruct the room.
- Any physics body that fits on the pressure plate may hold the switch down.

These are acceptable emergent outcomes unless they make the intended route impossible to understand.

## Known v1 limitations

- The puzzle uses procedural prototype geometry and labels.
- The copper fuse has generous terminal contact radii for controller placement.
- Soul Grip rotation is yaw-only in this version.
- The puzzle does not save completion or alter story progression.
- F8 is a development reset rather than a player-facing rewind mechanic.
