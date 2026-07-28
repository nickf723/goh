# Grace Vertical Motion Continuity v1

## Purpose

Grace's ordinary jump previously consisted of one vertical velocity assignment followed by uniform gravity. It worked, but launch, ascent, apex, fall, and landing were not represented as one continuous authored motion.

Vertical Motion Continuity v1 gives those moments a shared profile and controller while preserving the existing physical character body, maximum run speed, collision dimensions, and nominal full-jump launch velocity.

The resulting grammar is:

```text
Buffered intention
      ↓
Launch
      ↓
Rising
      ↓
Apex
      ↓
Falling
      ↓
Landing
      ↓
Ground motion
```

## Shared components

### VerticalMotionProfile

```text
scripts/player/vertical_motion_profile.gd
```

The reusable profile owns:

- coyote time;
- jump-input buffering;
- launch-velocity scaling;
- early-release jump cutting;
- rising, apex, falling, and cut-jump gravity scales;
- terminal fall speed;
- landing-impact thresholds;
- landing-pose duration;
- wire-presentation values.

Grace uses:

```text
data/player/grace_vertical_motion_profile.tres
```

Future playable gods can use the same controller with different vertical identities. A light Air avatar can linger longer near the apex, while a heavy Metal avatar can rise and settle with much greater commitment.

### PlayerVerticalMotionController

```text
scripts/player/player_vertical_motion_controller.gd
```

The shared player installs the controller at:

```text
Player/VerticalMotionController
```

The controller owns vertical state, jump requests, coyote time, input buffering, gravity selection, jump release, apex detection, fall-speed memory, and landing classification. The `CharacterBody3D` still performs physical movement and collision.

### GraceVerticalMotionVisual

```text
scripts/visuals/grace_vertical_motion_visual.gd
```

The wire scene now uses a thin subclass over the existing Grace wire-motion visual. It removes its prior vertical accent, lets the ordinary animation and combat stack resolve, then adds the current launch, rise, apex, fall, or landing performance.

Combat footwork, weapon control, and dodge presentation remain authoritative. Vertical accents deliberately stand down during those authored actions rather than fighting them for ownership of Grace's legs.

### PlayerAerialLocomotionVertical

```text
scripts/player/player_aerial_locomotion_vertical.gd
```

The advanced aerial controller extends the existing double-jump, hover, flight, controlled-descent, and airflow system. It reuses the same vertical controller for ordinary jumping, coyote jumps, air jumps, gravity shaping, and landing memory.

When advanced aerial abilities are unlocked, the first ground jump still begins through the standard player path. The aerial controller takes over once Grace is airborne, preserving the shared ground motor on stairs and ordinary terrain.

## Input forgiveness

### Coyote time

Grace may still jump for `0.12` seconds after walking from a ledge. The request uses the same launch velocity and consumes the coyote window immediately.

### Jump buffer

A jump pressed up to `0.12` seconds before touching down remains queued. On the next grounded physics frame, the buffered request launches Grace instead of being lost between frames.

The buffer is short enough to preserve deliberate timing while removing the brittle requirement to press Jump on one exact landing frame.

## Variable jump height

Holding Jump preserves the full launch arc.

Releasing Jump while Grace is still rising queues an early-release cut. Once the minimum hold time has elapsed, upward velocity is multiplied by the profile's release factor and stronger rising gravity completes the short hop.

This creates two useful outcomes from one input:

```text
Tap Jump   → compact obstacle hop
Hold Jump  → full traversal jump
```

The full held jump retains the existing `4.5` launch velocity. The release mechanic only shortens the arc when the player asks it to.

## Shaped gravity

Gravity now changes by phase:

- `rising`: baseline gravity preserves the familiar launch;
- `apex`: reduced gravity creates a small readable crest without materially inflating jump height;
- `falling`: stronger gravity restores decisive downward motion;
- `jump cut`: early-release gravity prevents a short hop from floating after velocity is reduced.

A terminal fall-speed cap prevents unbounded downward velocity from accumulating during very long falls. It is a numerical safety limit, not fall-damage immunity.

## Landing classification

The controller remembers the strongest downward speed reached before contact and classifies the landing as:

```text
settled
light
firm
hard
```

The impact speed determines a normalized landing strength and pose duration. Small steps can settle without triggering a theatrical crouch, while a high drop produces a stronger compression, ring, and camera response.

The landing classification is presentation metadata in v1. It does not add fall damage, stagger, or recovery lock.

## Motion and combat integration

The free-aim player controller now applies the vertical contract during:

- standard locomotion;
- airborne legacy attack movement;
- dodge travel;
- hit reactions;
- grounded attack footwork;
- stair and floor-snap movement.

Swimming, riding, climbing, tether traversal, and sustained flight advertise an external vertical state and retain ownership of their specialized movement.

The ground motor continues to own horizontal acceleration, braking, turning, and air steering. The vertical controller changes only the Y component and vertical state memory.

## Wire presentation

The wire rig now adds phase-specific secondary motion:

### Launch

- brief root compression;
- lowered center of mass;
- asymmetrical leg load;
- forward preparation through the torso.

### Rising

- slight vertical extension;
- motion-relative body lean;
- restrained lateral balance.

### Apex

- small float accent;
- reduced body tension;
- compact leg suspension.

### Falling

- progressive brace based on downward speed;
- extended opposing legs;
- lateral balance based on horizontal travel.

### Landing

- impact-strength root compression;
- torso absorption;
- widened foot placement;
- synchronized ground ring and camera impulse.

The accents are additive and removed before every new sample, preventing pose drift.

## Motion feedback

`PlayerMotionFeedback` now listens to exact vertical-controller signals.

- Jump launch creates a compact takeoff ring.
- Landing feedback uses the classified impact strength rather than waiting for an approximate visual-state transition.
- Existing footsteps, climbing motes, and landing camera impulse remain intact.

## Showcase

Open:

```text
scenes/levels/prototypes/prototype_animation_showcase_lab_v1.tscn
```

The eastern lane now contains:

- a cyan jump-launch line;
- a pink short-hop release line;
- a floating gold apex-height marker;
- six ordinary stair risers;
- a `2.10`-unit drop platform;
- an orange hard-landing target.

The HUD reports:

```text
vertical state
vertical velocity
gravity scale
phase progress
peak fall speed
coyote time
jump buffer
last jump kind
jump-cut state
landing kind
landing impact speed
landing strength
```

### Suggested review

1. Tap Jump at the cyan line and release near the pink line.
2. Hold Jump and compare the full arc with the short hop.
3. Watch the state change through Launch, Rising, Apex, Falling, and Landing.
4. Walk from a ledge and press Jump just after leaving it.
5. Press Jump shortly before landing to test buffering.
6. Jump while moving forward, sideways, backward, and while locked on.
7. Jump onto and off the existing landing steps.
8. Walk up the eastern staircase and drop from the top platform onto the orange target.
9. Compare low-step, medium-step, and platform-drop landing strength.
10. Dodge or attack during a jump and confirm authored combat poses remain in control.
11. Use aerial techniques and confirm the vertical state resumes afterward.
12. Test stairs immediately after landing and jump buffering immediately after a dodge.

## Automated regression

Run scene:

```text
scenes/tests/vertical_motion_smoke_test.tscn
```

Expected marker:

```text
VERTICAL_MOTION_SMOKE_TEST: PASS
```

The regression checks:

- profile validity;
- phase-specific gravity ordering;
- landing classification;
- full launch velocity;
- rising, apex, and falling state resolution;
- terminal fall-speed clamping;
- early-release jump cutting;
- coyote jumping;
- buffered landing jumps;
- hard-landing strength;
- shared-player installation;
- advanced aerial integration;
- wire-pose finiteness;
- motion-feedback synchronization;
- controller and visual diagnostics.

## Intentionally unchanged

- Grace's `4.5` full-jump launch velocity;
- horizontal maximum speed and ground-motion tuning;
- dodge distance, duration, and invulnerability;
- attack damage, hit geometry, timing, combos, and root-motion distance;
- spell costs and effects;
- collision dimensions;
- climbing, swimming, riding, and sustained-flight rules;
- fall damage and landing stagger;
- final character animation assets, sound, rumble, and production VFX.

## Next refinement

After manual vertical-motion tuning, the polished wire body has complete first-pass contracts for ground motion, stairs, dodge, attack footwork, jump, fall, and landing.

The next large slice can return to Divine Incarnation and build the first playable god prototype on top of those shared contracts rather than duplicating a second movement stack.
