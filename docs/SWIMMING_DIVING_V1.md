# Swimming and Diving v1

Run:

```text
scenes/levels/prototypes/prototype_swimming_lab_v1.tscn
```

## Shared aquatic locomotion

`PlayerSwimmingController` is installed on Grace's shared player scene. Entering a `SwimmingWaterVolume` transfers locomotion into water movement; exiting restores ordinary action control and leaves temporary wetness feedback.

## Movement

- Camera-relative surface swimming
- Underwater horizontal movement
- Hold jump to ascend
- Hold dodge to dive
- Hold guard while moving to sprint-swim
- Surface buoyancy and smooth water drag
- Grace rotates toward her actual swim direction
- Exhaustion disables sprinting
- Empty breath forces Grace upward instead of killing her immediately
- Jumping toward a marked pool ledge hands locomotion into climbing

## World volumes

Swimming volumes expose:

- surface height
- constant current velocity
- tangential swirl
- inward vortex pull
- a readable label for diagnostics

Overlapping volumes combine currents, allowing a calm pool to contain current channels and vortex pockets without replacing the main water body.

## Presentation

- Separate surface and underwater animation poses
- Alternating strokes and kicks
- Underwater horizontal body posture
- Rising bubbles
- Screen-space underwater tint
- Temporary wet sheen after leaving water
- Current, depth, breath, stamina, and wetness HUD values

## Laboratory route

1. Walk down the shallow entry steps.
2. Test surface swimming and sprinting.
3. Dive into the deep left pocket and feel the vortex.
4. Enter the right current tunnel.
5. Collect the glowing Abyss Pearl.
6. Surface near the rear stone wall.
7. Jump toward it and climb onto the exit platform.
8. Press F8 to reset.

## Controls

- Move: WASD / left stick
- Ascend: jump
- Dive: C / controller bottom face
- Sprint-swim: hold guard
- Ledge exit: jump toward climbable wall
- Reset: F8

## Automated contract scene

```text
scenes/tests/swimming_smoke_test.tscn
```

The test validates shared controller installation, water entry/exit, surface height, currents, both animation states, breath depletion, forced surfacing, wetness, and diagnostics.
