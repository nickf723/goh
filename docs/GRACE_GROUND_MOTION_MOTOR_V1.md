# Grace Ground Motion Motor v1

## Goal

Grace should respond immediately without snapping between complete velocities. The shared player now converts movement intention into a requested velocity, then resolves that request through a reusable motion profile.

The runtime path is:

```text
input intention
    -> analog shaping and directional speed
    -> requested planar velocity
    -> acceleration / turning / reversal / braking
    -> actual CharacterBody3D velocity
    -> step-up, collision, and visual feedback
```

## Shared components

- `scripts/player/ground_motion_profile.gd`
  - reusable data for maximum speed, acceleration, braking, reversal, turning, air control, lock-on movement, and action handoffs;
- `data/player/grace_ground_motion_profile.tres`
  - Grace's first tuned profile;
- `scripts/player/player_ground_motion_motor.gd`
  - stateful velocity resolver and diagnostics;
- `scripts/player/player_controller_free_aim.gd`
  - integrates the motor with normal movement, jumping, stairs, dodges, hit reactions, and authored attack movement;
- `scripts/visuals/grace_wire_motion_visual.gd`
  - reads motor intent for subtle braking, turning, and reversal posture.

The profile is avatar data rather than Grace-only controller logic. Future gods, companions, bosses, and playable bodies can use different profiles with the same motor.

## Grace v1 tuning

Grace retains a maximum ground speed of `5.0` world units per second.

Her initial response is immediate but partial. She receives a small starting velocity, then accelerates to maximum speed over several physics frames. Releasing movement uses stronger braking than acceleration, producing a planted stop without an ice-skating tail.

Distinct response paths exist for:

- acceleration from rest;
- cruising at the requested speed;
- braking when input is released or analog magnitude decreases;
- turning through a sharp angle;
- reversing through an opposing direction;
- gradual air steering and low air drag;
- lock-on strafing and backward movement;
- inherited velocity entering an attack lunge;
- dodge and hit-reaction velocity returning to normal control.

## Analog control

Controller magnitude survives the input path. A partial stick produces a partial target speed through an authored response exponent rather than being normalized immediately to full movement.

Keyboard movement remains full-strength and uses the same acceleration and braking rules.

## Lock-on behavior

When locked on, lateral and backward requests receive modest speed multipliers. Grace still reacts quickly, but circling does not outrun straight pursuit and retreat does not look identical to forward travel.

The motor does not rotate Grace. Existing camera and lock-on facing remain authoritative.

## Visual response

The wire rig now exposes the motor state in the animation showcase HUD:

- target speed;
- actual speed;
- analog input strength;
- turn angle;
- braking weight;
- reversal weight.

Grace's wire pose also receives a restrained secondary accent outside attacks:

- acceleration leans her slightly into intent;
- braking lowers and checks her torso;
- reversal compresses her center before redirecting;
- turning adds a small lateral lean and torso lead.

These accents are removed before each new procedural pose sample, so they do not accumulate or corrupt the base rig.

## Action handoffs

Attack lunges preserve a profile-defined portion of current movement before converging on authored combat motion. Once the lunge ends, the motor resumes from the velocity Grace actually has rather than resetting her to zero.

Dodge, hit, stair, jump, and air paths likewise feed their resulting planar velocity back into the motor. This allows normal locomotion to brake or redirect the handoff instead of creating a one-frame velocity corner.

## Showcase

Open and run:

```text
scenes/levels/prototypes/prototype_animation_showcase_lab_v1.tscn
```

The floor now includes:

- a green start line;
- an orange braking line;
- a violet reversal line;
- four figure-eight markers;
- the existing stair, landing, climb, dodge, and combat fixtures.

Suggested review:

1. Hold forward from rest and watch target speed separate from actual speed.
2. Release at the orange line and inspect the planted stop.
3. Flick directly backward at the violet line and watch the short compression before motion crosses zero.
4. Run repeated figure eights around the four markers.
5. Use a controller at partial stick magnitude and compare walking-speed requests with full travel.
6. Lock on and compare forward pursuit, lateral circling, and retreat.
7. Enter Light, Heavy, and dodge actions while moving, then continue or reverse immediately afterward.
8. Walk and attack up the existing stairs to verify step navigation remains intact.

## Regression

Focused scene:

```text
scenes/tests/ground_motion_motor_smoke_test.tscn
```

Expected marker:

```text
GROUND_MOTION_MOTOR_SMOKE_TEST: PASS
```

The regression checks:

- profile validity and shared-player installation;
- full and partial analog requests;
- lock-on strafe speed;
- acceleration without an instant full-speed snap;
- rapid planted braking;
- 180-degree reversal through zero;
- 90-degree turning response;
- air momentum retention;
- external velocity capture;
- attack and dodge handoff metadata;
- wire-animation diagnostics.

## Intentionally unchanged

- maximum travel speed;
- jump height and gravity;
- dodge duration, distance, and invulnerability;
- weapon timing, hit geometry, damage, and combo links;
- spell behavior;
- collision dimensions;
- camera and lock-on target selection;
- swimming, riding, climbing, mantling, and tether locomotion.

## Next pass

After manual tuning of this profile, the strongest next target is combat footwork and attack-root motion: stance width, planted support legs, approach distance curves, impact weight transfer, and recovery control.
