# Grace Dodge Motion and Recovery v1

## Purpose

Grace's dodge is now a profile-driven physical action rather than one constant-speed displacement with an unrelated invulnerability timer.

The v1 contract separates:

1. requested direction;
2. direction variant;
3. normalized dodge progress;
4. launch, travel, landing, and recovery phases;
5. speed-curve sampling;
6. late steering;
7. invulnerability timing;
8. action follow-up and chain windows;
9. exit momentum through the existing ground-motion motor.

The shared player uses:

```text
data/player/grace_dodge_motion_profile.tres
```

Future playable gods can use the same controller with different profiles.

## Motion curve

Grace keeps approximately the same compact dodge scale, but speed is no longer constant.

- `launch` begins immediately with substantial speed and rises into the peak;
- `travel` carries the fastest protected displacement;
- `landing` deliberately sheds speed;
- `recovery` finishes with a small residual velocity that hands cleanly back to locomotion.

The controller normalizes the sampled curve so authored distance remains stable even when curve multipliers are retuned.

Current baseline:

```text
distance = 1.72
duration = 0.28
cooldown = 0.14
```

Forward, side, backward, and neutral lock-on backsteps use small distance multipliers. This keeps a forward escape expressive while making combat strafes and retreats more controlled.

## Direction and lock-on behavior

Outside lock-on, movement input resolves camera-relative dodge direction.

During lock-on, movement resolves relative to Grace's facing:

- forward approaches the target;
- left and right produce lateral combat dodges;
- backward retreats;
- no movement input becomes a backstep.

Grace snapshots the initial direction. Late steering becomes available after the protected middle has begun, and it bends the exit rather than replacing the committed launch.

## Invulnerability

Invulnerability is authored in normalized dodge time:

```text
start = 0.10
end = 0.70
```

The launch begins vulnerable, the central travel is protected, and landing and recovery are vulnerable again. The controller starts the existing `GameState` invulnerability timer only when the normalized window opens.

The wire rig increases emission during the protected interval. This makes timing visible without a dedicated meter and keeps the gameplay check authoritative in `PlayerDefenseController`.

## Follow-ups

The profile currently exposes four kinds of exit readiness:

- weapon technique;
- spell cast;
- guard;
- chained dodge.

The existing dash-strike route still calls `cancel_into_weapon_technique()`, preserving the dodge direction for attack motion.

Cast and guard input pressed shortly before their recovery windows is buffered by `PlayerDodgeController`. When the window opens, the controller ends the dodge before asking the ability or defense component to begin the requested action.

A second dodge may be buffered near the end of the first. Grace currently allows two consecutive dodges, each paying its normal stamina cost. The second dodge snapshots the new requested direction and starts a fresh curve.

## Terrain and movement integration

The existing free-aim controller still owns physical movement and collision. During a dodge it requests the current sampled velocity from `PlayerDodgeController`, then applies:

- stair stepping;
- normal `CharacterBody3D` wall collision;
- floor snap;
- ground-motion exit retention.

The dodge controller does not teleport Grace and does not bypass collision.

## Presentation

The wire rig reads dodge diagnostics after gameplay updates and adds restrained secondary motion:

- launch compression;
- directional body lean;
- landing compression;
- protected-window emission;
- phase, progress, kind, speed, chain, and follow-up diagnostics.

The existing procedural dodge pose remains the broad silhouette. The v1 accents make its timing agree with the new motor rather than replacing the whole animation layer.

## Showcase

Open:

```text
scenes/levels/prototypes/prototype_animation_showcase_lab_v1.tscn
```

The far end of the runway now contains:

- a cyan launch line;
- a gold protected-travel line;
- a violet recovery line;
- left and right lateral markers;
- a collision wall for stop and corner behavior.

The HUD reports:

```text
phase
kind
progress
speed
I-frame state
chain count
attack / cast / guard / chain readiness
buffered follow-up
```

Suggested review:

1. Dodge forward from rest and while running.
2. Compare forward, side, backward, and no-input lock-on dodges.
3. Hold a new direction late in the dodge and inspect the exit bend.
4. Dodge into the wall from several distances and angles.
5. Dodge over ordinary stair risers and back down them.
6. Press dodge again shortly before recovery to test the two-dodge chain.
7. Press Light during a dodge to test the existing dash-strike route.
8. Press Cast shortly before the cast window.
9. Hold Guard shortly before the guard window.
10. Dodge while locked on and confirm Grace keeps facing the target.

## Automated regression

Run scene:

```text
scenes/tests/dodge_motion_smoke_test.tscn
```

Expected marker:

```text
DODGE_MOTION_SMOKE_TEST: PASS
```

The regression checks:

- profile validity and ordered phases;
- direction distance variants;
- launch and peak speed relationship;
- delayed normalized invulnerability;
- late steering;
- chain timing and stamina-backed restart;
- weapon-technique cancellation;
- curve-integrated distance;
- natural recovery and action-state cleanup;
- installation on the shared player;
- wire diagnostics and protected-window emission.

## Intentionally unchanged

- weapon damage, hit geometry, combo data, and attack timing;
- Grace's maximum run speed, acceleration profile, gravity, and jump height;
- collision dimensions;
- spell costs and effects;
- guard balance;
- final sound, camera shake, controller rumble, and production animation.

## Next refinement

After manual dodge tuning, the next locomotion slice should be combat footwork and attack-root motion. The dodge and ground motors now provide clean entry and exit velocities for that work.
