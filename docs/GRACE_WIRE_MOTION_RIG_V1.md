# Grace Wire Motion Rig v1

## Purpose

Grace is temporarily represented by a luminous wire skeleton so movement, combat poses, weapon alignment, grounding, and transition quality can be judged without costume geometry concealing the underlying motion.

This is a production-development rig, not Grace's final visual design. The previous `grace_visual_v1.tscn` remains in the repository for later reference and art reintegration.

## Player-facing change

The shared player scene now instances:

```text
scenes/actors/player/grace_wire_visual_v1.tscn
```

Every scene using the shared player therefore receives the same wire motion rig.

The rig displays:

- a center spine from pelvis through head;
- two-segment arms with solved elbows;
- two-segment legs with solved knees;
- hands, ankles, feet, and visible joint markers;
- left and right limb color separation;
- outfit identity through wire-palette changes instead of temporary costume meshes;
- the equipped weapon attached to the animated right-hand orientation.

## Architecture

`GraceWireMotionVisual` extends the existing `StylizedActorVisual` state resolver. Current locomotion, traversal, combat, casting, item, damage, swimming, riding, and defeat states remain authoritative.

`GraceWireSkeletonRenderer` converts the animated control pivots into a canonical 19-joint diagnostic pose. Elbows and knees use a two-bone geometric solve with stable preferred bend directions. Eighteen rendered segments connect the resulting joint set.

The current player-motion stack separates four layers:

1. `PlayerGroundMotionMotor` resolves movement intention into planar velocity.
2. `CharacterBody3D` remains responsible for collision and physical movement.
3. `StylizedActorVisual` resolves presentation states and target poses.
4. `GraceWireSkeletonRenderer` makes the resulting humanoid motion legible.

A future skinned Grace model can consume the same motion and pose contracts instead of forcing combat and locomotion to be retuned around finished art.

## Grounding pass

The shared visual baseline is aligned to the bottom of Grace's capsule so the joint spheres no longer begin below a flat floor.

During grounded states, the renderer probes beneath each ankle and toe independently. A valid floor hit adjusts only that contact point, then recomputes the corresponding knee. This gives the wire rig lightweight adaptation to:

- flat floors;
- shallow slopes;
- stairs and small ledges;
- landing compression;
- guard, dodge, attack, cast, and locomotion poses.

The foot segment can tilt between its ankle and toe probes, which makes surface angle visible without rotating Grace's whole collision body. Corrections are range-limited and smoothed so distant terrain cannot pull a foot downward and minor height changes do not create jitter.

Ground probing is disabled during jumping, falling, climbing, mantling, swimming, riding, flight, and defeat. Airborne attacks and hit reactions therefore remain airborne rather than having their feet magnetized to the nearest floor.

This is visual grounding only. It does not alter collision, movement, slope handling, jump physics, or gameplay position.

## Step navigation pass

`PlayerStepUpController` gives the shared player a narrow physical stair contract instead of requiring a jump for every vertical riser.

Before an ordinary grounded move, dodge, or authored attack lunge, the controller:

1. detects a mostly vertical obstruction in the requested direction;
2. verifies that Grace has overhead clearance;
3. verifies that her capsule can occupy the raised forward position;
4. searches downward for a walkable landing surface;
5. raises the body by the measured step height before normal movement continues.

The default maximum rise is `0.40` world units, enough for the animation-showcase steps and ordinary architectural stairs while remaining too small to replace jumping or mantling. The shared character also uses a modest floor snap so descending steps remains continuous.

This is gameplay movement rather than visual-only grounding, but it does not change Grace's jump height, collision dimensions, climbing permissions, or combat timings.

## Ground motion motor pass

Grace's ordinary movement no longer assigns complete horizontal velocity every physics frame. `PlayerGroundMotionMotor` now distinguishes:

- acceleration from rest;
- cruising at requested speed;
- braking after input release;
- sharp turns;
- 180-degree reversals;
- analog stick magnitude;
- lock-on strafing and retreat;
- air steering and momentum retention;
- attack, dodge, and hit-reaction handoffs.

Grace keeps the same `5.0` maximum travel speed. Her acceleration is fast enough to preserve responsiveness, while braking is stronger and reversals cross through zero instead of teleporting between opposing velocities.

The wire visual reads the motor's smoothed intent weights for restrained acceleration lean, planted braking, reversal compression, and turn posture. The full implementation and tuning notes live in:

```text
docs/GRACE_GROUND_MOTION_MOTOR_V1.md
```

## Player-driven sword poses

The practice sword no longer supplies nearly all visible motion through a rotating weapon pivot. Each authored sword attack names a whole-body control profile in `WeaponCharacterPoseCatalog`.

A profile coordinates:

- anticipation through the torso and head;
- shoulder-driven cuts rather than wrist-only arcs;
- a solved hand path that gives the elbow useful work;
- counterbalancing motion from the free arm;
- a small residual weapon-local rotation for grip articulation;
- a quiet windup followed by a trail that begins with the active cut.

`PlayerWeaponControlAnimator` takes control only when an attack has an authored profile. Hammer, lance, and future weapon attacks without a profile retain their existing presentation until they receive their own pass.

The first sword set covers Opening Cut, Returning Cut, Rising Cut, Circular Cut, Reprise Thrust, Guardbreaker, Rising Break, Crowd Cleave, Driving Thrust, and Orbit Finisher. Damage, hit geometry, stamina costs, combo links, active frames, recovery frames, and cancellation rules are unchanged.

## Outfit behavior during the wire phase

`GraceWireEquipmentAppearance` preserves outfit feedback without adding costume meshes over the diagnostic skeleton:

- default exploration appearance uses the baseline wire palette;
- Traveler's Coat shifts the rig toward teal, leather, and brass;
- Apprentice Robe shifts the rig toward violet, cyan, and gold;
- Ironweave Jacket shifts the rig toward steel and red.

The actual outfit models remain future art work.

## Validation

The rig and integrated combat regression is:

```text
scenes/tests/grace_animation_smoke_test.tscn
```

The focused ground-motion regression is:

```text
scenes/tests/ground_motion_motor_smoke_test.tscn
```

Together they verify:

- installation on the shared player;
- all existing presentation states;
- exactly 19 joints and 18 bone segments;
- finite joint solutions in every forced pose;
- both feet contacting a known flat floor without penetrating or hovering;
- grounding during locomotion and grounded action states;
- grounding release during climb and mantle states;
- a measured physical step without jumping;
- authored pose coverage for every practice-sword attack;
- torso, hand, and weapon motion changing across windup and strike;
- delayed slash-trail activation during the active phase;
- analog target-speed shaping;
- acceleration, braking, turning, and reversal response;
- air and external velocity handoffs;
- animation, grounding, step, weapon-control, and motion diagnostics.

Expected terminal markers:

```text
GraceAnimationSmokeTest: PASS
GROUND_MOTION_MOTOR_SMOKE_TEST: PASS
```

## Manual review

Open:

```text
scenes/levels/prototypes/prototype_animation_showcase_lab_v1.tscn
```

Review these in order:

1. Stand still and confirm both foot joints rest above the surface.
2. Accelerate from the green line and compare target speed with actual speed.
3. Release movement at the orange line and inspect the planted stop.
4. Reverse at the violet line and watch Grace compress while velocity crosses zero.
5. Run figure eights around the four blue markers.
6. Use partial controller input and compare low-speed travel with a full stick.
7. Walk up and down every landing step without jumping.
8. Jump from each landing step and compare small and hard landing compression.
9. Climb and mantle the wall, confirming the feet release from ground probing.
10. Perform the complete Light and Heavy sword branches while moving.
11. Enter and exit attacks, dodges, and lock-on strafing without stopping first.
12. Press `P` to cycle deterministic poses and `O` to restore live control.
13. Use the existing reset action to restore the course.

## Intentionally unchanged

- player collision dimensions and spatial profile;
- maximum movement speed, gravity, and jump height;
- weapon damage, hit geometry, timing, and combo behavior;
- dodge duration, distance, and invulnerability;
- spell behavior and costs;
- camera, lock-on targeting, swimming, riding, climbing, mantling, and recovery mechanics;
- Grace's final face, body, clothing, hair, and material direction.

## Next refinement axis

With grounding, stairs, sword ownership, and ground-motion response established, the next pass should proceed in this order:

1. combat footwork and attack-root motion curves;
2. dodge startup, travel curve, and recovery control;
3. remaining weapon-class hand paths and body weight transfer;
4. jump, fall, and landing continuity;
5. transition interruption and animation-cancel readability;
6. final skinned-character retargeting.
