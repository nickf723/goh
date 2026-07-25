# Climbing and Mantling v1

Run:

```text
scenes/levels/prototypes/prototype_climbing_lab_v1.tscn
```

## Traversal contract

Grace can grab a climbable wall by jumping or falling toward it while holding forward. Once attached:

- movement input climbs vertically and laterally;
- stamina drains according to movement and surface material;
- remaining still recovers stamina slowly;
- jump launches Grace upward and away from the wall;
- dodge deliberately drops;
- reaching a valid top surface begins a smooth mantle;
- exhaustion releases the wall automatically.

The same controller is installed on the shared player scene, so authored climbable surfaces can use this mechanic outside the laboratory.

## Surface profiles

- **Wood:** strong grip and reduced stamina cost.
- **Stone:** neutral grip and ordinary cost.
- **Metal:** climbable with substantially increased cost.
- **Wet stone:** increased cost plus continuous downward sliding.
- **Ice:** refuses the grab in v1.

The wet bay can be toggled between rain-slick and dry with R, demonstrating that weather can change traversal properties without replacing the wall.

## Controls

- Grab: jump or fall toward a wall while holding forward
- Climb: WASD / left stick
- Wall jump: jump while attached
- Drop: C / controller bottom face
- Toggle wet wall: R
- Reset: F8

The compact HUD reports traversal state, surface, stamina multiplier, slide speed, and current stamina.

## Automated contract scene

```text
scenes/tests/climbing_smoke_test.tscn
```

The smoke test validates controller installation, material profiles, stamina expenditure, and climb-state reset.
