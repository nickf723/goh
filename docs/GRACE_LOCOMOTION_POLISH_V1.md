# Grace Locomotion Polish v1

## Goal

Grace Locomotion Polish adds a small additive presentation layer to ordinary grounded movement so the procedural body reads with more weight and less pendulum-like foot motion.

It does not replace `StylizedActorVisual` and does not own animation state.

## Additive contract

The polish node runs before Grace's existing visual process to remove the previous frame's additive offsets, then schedules the current polish after the base pose has been authored.

This keeps the base animation authoritative and prevents additive offsets from accumulating over time.

## Grounded locomotion features

### Weight transfer

During locomotion, Grace's body shifts a small distance toward the currently planted leg and adds a restrained lateral roll.

### Foot planting illusion

The planted leg settles slightly while the opposite swing leg lifts a few millimeters. This does not perform IK and does not change collision. It is a lightweight presentation cue intended for the current procedural body.

### Turn anticipation

Torso yaw counter-rotates against turning velocity while the head leads the turn more strongly. This gives direction changes a short anticipation/follow-through relationship without steering the player or camera.

### Acceleration shift

The body receives a tiny fore/aft positional offset from the existing smoothed acceleration signal already calculated by `StylizedActorVisual`.

## State ownership

The polish is allowed only in:

```text
idle
locomotion
landing
```

Action-authored states such as attack, cast, guard, dodge, climb, swim, flight, hit, and defeated reject the additive layer.

## F7 quality

Grace Locomotion Polish follows Lighting Director quality so it participates in the existing benchmark presets.

```text
Performance  0%
Balanced    65%
Cinematic  100%
```

This means F9 BASELINE shows the original Grace locomotion while HERO shows the full polish.

## Ownership boundary

Grace Locomotion Polish may:

- add small local position/rotation offsets after the base visual pose;
- use existing movement weight, stride phase, acceleration, and turn velocity;
- scale those offsets with renderer quality;
- restore its exact previous additive offsets before the next base pose.

It must not:

- change actor velocity or rotation;
- change collision;
- choose animation state;
- alter attack/cast/dodge/climb/swim/flight poses;
- own gameplay movement.

## Validation

```text
res://scenes/tests/grace_locomotion_polish_smoke_test.tscn
```

The regression verifies Performance/Balanced/Cinematic scaling, exact additive restoration, complementary stance weights, stronger head turn anticipation, and action-state exclusion.
