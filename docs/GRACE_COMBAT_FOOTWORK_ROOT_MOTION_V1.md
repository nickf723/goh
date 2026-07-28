# Grace Combat Footwork and Attack Root Motion v1

## Purpose

Grace's sword attacks now distribute authored movement through a coordinated lower-body action instead of applying one flat velocity while the upper body performs an unrelated pose.

The v1 contract separates:

1. weapon damage, timing, and hit geometry;
2. authored attack movement distance and duration;
3. a reusable root-motion curve;
4. committed attack direction with limited late steering;
5. collision-aware travel;
6. lower-body plant, drive, and settle poses;
7. upper-body sword control;
8. hand and weapon presentation;
9. return to the shared ground-motion motor.

The change is presentation and motion-distribution work. Practice-sword damage, stamina costs, combo links, attack ranges, hit cones, active frames, recovery frames, cancel windows, and authored movement distances remain unchanged.

## Shared components

### CombatFootworkProfile

```text
scripts/player/combat_footwork_profile.gd
```

The avatar-level profile owns:

- late-steering timing;
- steering strength and maximum turn angle;
- wall-block detection;
- safe movement-duration bounds;
- pose strength and response.

Grace uses:

```text
data/player/grace_combat_footwork_profile.tres
```

Future gods and other playable avatars can reuse the controller with different profiles without changing weapon definitions.

### CombatFootworkCatalog

```text
scripts/weapons/combat_footwork_catalog.gd
```

The catalog owns reusable attack styles. Each style defines:

- plant, drive, and settle speed multipliers;
- the planted foot;
- steering resistance;
- root position and rotation;
- body position and rotation;
- left and right leg rotations;
- left and right hip-pivot offsets;
- windup, strike, and recovery samples.

The practice sword currently provides ten authored styles:

```text
sword_cut_right
sword_cut_left
sword_rising_right
sword_spin_right
sword_thrust
sword_overhead
sword_rising_heavy
sword_cleave_left
sword_thrust_heavy
sword_orbit
```

The ids intentionally match the existing whole-body sword control profiles. Upper-body control and lower-body footwork remain separate catalogs so another avatar can reuse the same attack graph while expressing a different physical style.

### PlayerCombatFootworkController

```text
scripts/player/player_combat_footwork_controller.gd
```

The controller is installed on the shared player as:

```text
Player/CombatFootworkController
```

When `WeaponController` requests its existing combat movement, the player first checks whether the current attack has an authored footwork profile. Profiled grounded attacks use the new controller; unprofiled and airborne attacks retain the legacy movement path.

## Root-motion curve

The attack's existing `movement_distance` and `movement_duration` remain authoritative.

The footwork style reshapes that motion into three sections:

```text
Plant → Drive → Settle
```

- **Plant** begins with restrained travel while the legs establish support.
- **Drive** accelerates the root as Grace commits body weight through the attack.
- **Settle** deliberately removes speed so the attack hands control back cleanly.

The controller numerically samples each style and normalizes base speed against the curve's average multiplier. Retuning a curve therefore changes the feel of the motion without silently changing its intended total distance.

A partial final physics frame is scaled so frame rate does not add extra travel at the end of the authored duration.

## Direction and steering

The attack direction is committed when the attack begins. This direction remains aligned with the weapon controller's targeting and hit geometry.

Late steering becomes available only during the configured middle-to-late portion of root motion. Input can bend the exit, but:

- steering strength is style-specific;
- turn rate is limited per frame;
- total deviation from the original attack direction is capped;
- thrusts and heavy finishers resist steering more strongly than light cuts.

This preserves player agency without turning committed attacks into homing vacuum cleaners.

## Collision and stairs

The free-aim player controller remains the sole owner of physical movement. During active attack root motion it applies:

1. the sampled footwork velocity;
2. the existing step-up controller;
3. normal `CharacterBody3D` collision and sliding;
4. floor snap;
5. post-move distance measurement;
6. shared ground-motion diagnostics.

The footwork controller compares expected and actual forward displacement. Repeated near-zero travel marks the attack as blocked and ends remaining root translation, preventing Grace from grinding against a wall for the rest of the attack.

The visual pose may continue through recovery after physical travel ends. This preserves a planted finish without freezing ordinary locomotion longer than the existing movement duration.

## Sword presentation stack

A profiled sword attack now passes through four coordinated layers:

```text
WeaponAttackDefinition
        ↓
WeaponCharacterPoseCatalog
        ↓
CombatFootworkCatalog
        ↓
GraceWireMotionVisual + PlayerWeaponControlAnimator
```

- `WeaponCharacterPoseCatalog` controls torso, head, shoulders, hands, and free-arm counterbalance.
- `CombatFootworkCatalog` controls weight transfer, pelvis/root accents, stance width, and leg action.
- `GraceWireMotionVisual` combines both without letting one overwrite the other.
- `PlayerWeaponControlAnimator` retains only the smaller weapon-local articulation and active-phase trail.

The result should read as:

```text
feet establish support
hips and torso initiate
shoulder carries the hand
hand carries the sword
blade completes the path
```

## Practice-sword coverage

| Attack | Footwork identity |
|---|---|
| Opening Cut | right-foot plant and lateral weight transfer |
| Returning Cut | mirrored left-foot return |
| Rising Cut | compressed load into an upward drive |
| Circular Cut | wide planted pivot |
| Reprise Thrust | measured rear-to-front lunge |
| Guardbreaker | bilateral overhead plant |
| Rising Break | deeper heavy rising drive |
| Crowd Cleave | wide left-leading cleave stance |
| Driving Thrust | strongly committed long thrust |
| Orbit Finisher | two-foot pivot with limited steering |

## Showcase

Open:

```text
scenes/levels/prototypes/prototype_animation_showcase_lab_v1.tscn
```

The western side of the course now contains:

- a green plant line;
- an amber drive line;
- a violet settle line;
- blue and pink stance markers;
- a wall for blocked-root-motion testing.

The HUD reports:

```text
footwork profile
plant / drive / settle phase
planted foot
normalized root-motion progress
sampled speed
requested distance
expected distance
actual distance
steering angle
blocked state
```

### Suggested review

1. Perform Opening Cut from rest and watch the right foot establish support before the body crosses the strike.
2. Continue the Light sequence and confirm the plant alternates rather than both legs drifting together.
3. Compare Rising Cut with Rising Break. The heavy version should load lower and commit more strongly.
4. Compare Reprise Thrust with Driving Thrust. Both should travel through a rear-to-front push, while the heavy thrust should resist redirection.
5. Perform Circular Cut and Orbit Finisher near the stance markers. The feet should widen and support rotation rather than following the sword as one rigid bundle.
6. Attack while already moving forward, sideways, and backward. Entry should remain aligned with the attack direction without a one-frame velocity corner.
7. Hold a slightly different direction during the latter half of a light attack. The exit should bend modestly rather than swivel.
8. Repeat with Driving Thrust and Orbit Finisher. Their steering should be much more restrained.
9. Attack into the footwork wall from several distances and angles. Root translation should stop after collision without repeated wall shudder.
10. Attack up and down the ordinary stairs. Step-up and floor snap should remain intact.
11. Chain Light and Heavy branches. Each new attack should establish its own stance rather than inheriting stale leg offsets.
12. Dodge into a dash strike and confirm the dodge direction transfers into the attack without losing the attack's authored plant and settle.

## Automated regression

Run scene:

```text
scenes/tests/combat_footwork_smoke_test.tscn
```

Expected marker:

```text
COMBAT_FOOTWORK_SMOKE_TEST: PASS
```

The regression checks:

- Grace profile validity;
- catalog validity;
- complete practice-sword coverage;
- plant, drive, and settle curve relationships;
- curve-integrated authored distance;
- lower-body and root pose differences between windup and strike;
- wire-rig finite pose output;
- limited late steering;
- repeated wall-block detection;
- visual pose persistence after physical root motion stops;
- shared-player installation;
- controller and animation diagnostics;
- clean cancellation and action-state release.

## Intentionally unchanged

- sword damage and stance damage;
- hit geometry and target selection;
- attack startup, active, and recovery timing;
- combo graph and input buffering;
- cancellation permissions;
- authored movement distances and movement durations;
- Grace's maximum run speed and ground-motion tuning;
- dodge distance and I-frame timing;
- gravity, jump height, collision dimensions, climbing, swimming, and riding;
- final animation assets, audio, camera impact, rumble, and production VFX.

## Next refinement

After manual tuning, the next large locomotion slice should be jump, fall, and landing continuity, followed by a return to Divine Incarnation using the shared ground, dodge, and combat-footwork contracts for the first playable god prototype.
