# Grace Animation and Movement Presentation v2

Run the showcase:

```text
scenes/levels/prototypes/prototype_animation_showcase_lab_v1.tscn
```

## Shared presentation system

Grace's procedural visual now resolves and blends these states:

- idle and locomotion
- jump, fall, and landing
- surface swimming and underwater strokes
- climb and mantle
- light/heavy weapon attacks
- guard and dodge
- hit and defeated
- cast and item use
- interaction and flight
- exhaustion

The visual controller remains attached to `grace_visual_v1.tscn`, while motion feedback is installed on the shared player scene. Every level using Grace receives the upgrade automatically.

## Motion improvements

- Movement weight blends instead of snapping between idle and stride.
- Stride phase advances with movement instead of being derived from absolute time.
- Acceleration and braking influence torso posture.
- Rapid turning creates readable lateral lean.
- Falling velocity is remembered so landings scale with impact speed.
- Landing poses compress Grace before recovering.
- Climbing alternates hands and feet.
- Mantling follows the actual two-stage climb progress.
- Exhaustion has its own low, breathing-heavy pose.
- Upper-body action poses continue to coexist with locomotion.

## Character response

- Eyes blink procedurally.
- Brows and mouth react to combat, casting, climbing, damage, exhaustion, and defeat.
- Hair locks and sash respond more strongly during traversal and impacts.
- Weapon and VFX anchors continue following the animated hands, chest, head, and feet.

## Motion feedback

`PlayerMotionFeedback` adds lightweight presentation without particle-system dependencies:

- alternating footfall pulses;
- landing rings scaled by impact;
- subtle landing camera impulse;
- alternating climbing grip motes;
- transition and feedback signals for later audio integration;
- a strict live-effect cap.

## Showcase controls

- Use normal movement, jump, climb, attack, guard, dodge, and spell controls.
- P cycles deterministic pose previews.
- O clears the preview and restores live state resolution.
- F8 resets the course.

The showcase contains a runway, turning guides, landing steps, a wood climbing wall, and a combat dummy.

## Automated contract scene

```text
scenes/tests/grace_animation_smoke_test.tscn
```

The test verifies shared component installation, every presentation state, climbing and mantle resolution, facial pivots, motion diagnostics, and feedback diagnostics.
