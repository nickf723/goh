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

The rig intentionally separates three layers:

1. The `CharacterBody3D` remains responsible for collision and movement.
2. `StylizedActorVisual` remains responsible for state selection and target poses.
3. `GraceWireSkeletonRenderer` makes the resulting humanoid motion legible.

A future skinned Grace model can consume the same pose contract instead of forcing combat and locomotion to be retuned around finished art.

## Grounding pass

The shared visual baseline is aligned to the bottom of Grace's capsule so the joint spheres no longer begin below a flat floor.

During grounded states, the renderer also probes beneath each ankle and toe independently. A valid floor hit adjusts only that contact point, then recomputes the corresponding knee. This gives the wire rig lightweight adaptation to:

- flat floors;
- shallow slopes;
- stairs and small ledges;
- landing compression;
- guard, dodge, attack, cast, and locomotion poses.

The foot segment can tilt between its ankle and toe probes, which makes surface angle visible without rotating Grace's whole collision body. Corrections are range-limited and smoothed so distant terrain cannot pull a foot downward and minor height changes do not create jitter.

Ground probing is disabled during jumping, falling, climbing, mantling, swimming, riding, flight, and defeat. Airborne attacks and hit reactions therefore remain airborne rather than having their feet magnetized to the nearest floor.

This is visual grounding only. It does not alter collision, movement, slope handling, jump physics, or gameplay position.

## Outfit behavior during the wire phase

`GraceWireEquipmentAppearance` preserves outfit feedback without adding costume meshes over the diagnostic skeleton:

- default exploration appearance uses the baseline wire palette;
- Traveler's Coat shifts the rig toward teal, leather, and brass;
- Apprentice Robe shifts the rig toward violet, cyan, and gold;
- Ironweave Jacket shifts the rig toward steel and red.

The actual outfit models remain future art work.

## Validation

The focused regression scene is:

```text
scenes/tests/grace_animation_smoke_test.tscn
```

It verifies:

- installation on the shared player;
- all existing presentation states;
- exactly 19 joints and 18 bone segments;
- finite joint solutions in every forced pose;
- correct vertical body ordering;
- both feet contacting a known flat test floor without penetrating or hovering;
- grounding during locomotion and grounded action states;
- grounding release during climb and mantle states;
- outfit palette forwarding;
- weapon-hand orientation synchronization;
- animation, grounding, and motion-feedback diagnostics.

Expected terminal marker:

```text
GraceAnimationSmokeTest: PASS
```

## Manual review

Open:

```text
scenes/levels/prototypes/prototype_animation_showcase_lab_v1.tscn
```

Review these in order:

1. Stand still on the runway and confirm both foot joints rest above the surface.
2. Start and stop repeatedly. Watch whether the pelvis, spine, knees, and feet settle cleanly.
3. Run tight circles and reverse direction. Watch torso lean, limb phase continuity, and foot jitter.
4. Cross the landing steps and inspect whether each foot adapts without stretching unnaturally.
5. Jump from each landing step. Compare small and hard landing compression.
6. Climb and mantle the wall. Confirm the feet release from ground probing immediately.
7. Test Light, Heavy, guard, dodge, and casting while moving.
8. Watch the weapon grip through attack windup, strike, and recovery.
9. Press `P` to cycle deterministic states and `O` to return to live control.
10. Use the existing reset action to restore the course.

## Intentionally unchanged

- player collision and spatial profile;
- movement speed, gravity, jump values, and slope physics;
- weapon movesets, damage, timing, and hit detection;
- spell behavior and costs;
- camera, lock-on, traversal, swimming, riding, and recovery mechanics;
- Grace's final face, body, clothing, hair, and material direction.

## Next refinement axis

With silhouette noise and flat-floor penetration removed, the next pass should tune the motion itself in this order:

1. ground acceleration, braking, and directional reversal;
2. combat footwork and attack-root motion;
3. dodge startup, travel curve, and recovery control;
4. weapon-specific hand paths and body weight transfer;
5. jump, fall, and landing continuity;
6. transition interruption and animation-cancel readability.
