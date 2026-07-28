# Grace Wire Motion Rig v1

## Purpose

Grace is temporarily represented by a luminous wire skeleton so movement, combat poses, weapon alignment, grounding, avatar identity, and transition quality can be judged without costume geometry concealing the underlying motion.

This is a production-development rig, not Grace's final visual design. The previous `grace_visual_v1.tscn` remains in the repository for later reference and art reintegration.

## Player-facing change

The shared player scene now instances:

```text
scenes/actors/player/grace_wire_visual_v1.tscn
```

Every scene using the shared player therefore receives the same wire motion rig and avatar-aware presentation contract.

The rig displays:

- a center spine from pelvis through head;
- two-segment arms with solved elbows;
- two-segment legs with solved knees;
- hands, ankles, feet, and visible joint markers;
- left and right limb color separation;
- outfit or avatar identity through wire-palette changes;
- the equipped weapon attached to the animated right-hand orientation.

## Architecture

`GraceIncarnationMotionVisual` extends the vertical and wire-motion stack over the existing `StylizedActorVisual` state resolver. Current locomotion, traversal, combat, casting, item, damage, swimming, riding, and defeat states remain authoritative.

`AvatarWireSkeletonRenderer` extends the canonical 19-joint diagnostic pose with avatar identity and reversible palette state. Elbows and knees still use the shared two-bone geometric solve. Eighteen rendered segments connect the resulting joint set.

The current player-motion and avatar stack separates eight layers:

1. `PlayerAvatarManager` applies a mortal or divine identity to the stable player proxy.
2. `PlayerGroundMotionMotor` resolves ordinary movement intention into planar velocity.
3. `PlayerVerticalMotionController` resolves jump intention, ascent, apex, fall, and landing state.
4. `PlayerDodgeController` resolves launch, protected travel, landing, recovery, and follow-up windows.
5. `PlayerCombatFootworkController` distributes attack travel through plant, drive, and settle root motion.
6. `CharacterBody3D` remains responsible for collision and physical movement.
7. `StylizedActorVisual` and the authored pose catalogs resolve presentation targets.
8. `AvatarWireSkeletonRenderer` makes the resulting humanoid motion and active avatar legible.

A future skinned Grace or god model can consume the same motion, avatar, and pose contracts instead of forcing combat and locomotion to be retuned around finished art.

## Grounding pass

The shared visual baseline is aligned to the bottom of Grace's capsule so the joint spheres no longer begin below a flat floor.

During grounded states, the renderer probes beneath each ankle and toe independently. A valid floor hit adjusts only that contact point, then recomputes the corresponding knee. This gives the wire rig lightweight adaptation to:

- flat floors;
- shallow slopes;
- stairs and small ledges;
- landing compression;
- guard, dodge, attack, cast, and locomotion poses.

The foot segment can tilt between its ankle and toe probes, which makes surface angle visible without rotating the whole collision body. Corrections are range-limited and smoothed so distant terrain cannot pull a foot downward and minor height changes do not create jitter.

Ground probing is disabled during jumping, falling, climbing, mantling, swimming, riding, flight, and defeat. Airborne attacks and hit reactions therefore remain airborne rather than having their feet magnetized to the nearest floor.

This is visual grounding only. It does not alter collision, movement, slope handling, jump physics, or gameplay position.

## Step navigation pass

`PlayerStepUpController` gives the shared player a narrow physical stair contract instead of requiring a jump for every vertical riser.

Before an ordinary grounded move, dodge, or authored attack lunge, the controller:

1. detects a mostly vertical obstruction in the requested direction;
2. verifies that the player has overhead clearance;
3. verifies that the capsule can occupy the raised forward position;
4. searches downward for a walkable landing surface;
5. raises the body by the measured step height before normal movement continues.

The default maximum rise is `0.40` world units, enough for the animation-showcase steps and ordinary architectural stairs while remaining too small to replace jumping or mantling. The shared character also uses a modest floor snap so descending steps remains continuous.

This is gameplay movement rather than visual-only grounding, but it does not change jump height, collision dimensions, climbing permissions, or combat timings.

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

## Vertical motion continuity pass

Ordinary jumping now uses the same profile-driven design language as ground motion and dodge:

```text
Buffered Intention → Launch → Rising → Apex → Falling → Landing
```

`PlayerVerticalMotionController` provides coyote time, landing-side input buffering, variable jump height, phase-shaped gravity, terminal fall-speed safety, impact memory, and light, firm, or hard landing classification.

The full held jump retains Grace's existing `4.5` launch velocity. Releasing Jump while rising creates a compact short hop. Apex gravity is slightly reduced for readability, while downward gravity becomes stronger after the crest so falling remains decisive.

`GraceVerticalMotionVisual` maps the controller's live state to the wire rig. Launch compresses before extending, the apex releases tension briefly, falling progressively braces the body, and landing strength controls the final absorption. Exact takeoff and landing signals drive motion rings and the existing camera impulse.

Advanced double jump, hover, airflow, flight, and controlled descent extend the same contract instead of maintaining a second unrelated vertical-motion memory. The complete implementation lives in:

```text
docs/GRACE_VERTICAL_MOTION_CONTINUITY_V1.md
```

## Dodge motion and recovery pass

Grace's dodge now uses a profile-driven curve rather than one constant-speed displacement. The controller resolves:

```text
Launch → Travel → Landing → Recovery
```

The committed opening direction can bend modestly during the late exit. Lock-on maps no-input dodge to a backstep, and directional variants adjust forward, side, backward, and backstep travel. Invulnerability is authored in normalized dodge time and is made visible through the wire rig's emission.

Buffered cast, guard, dash-strike, and second-dodge exits use explicit windows instead of frame-luck. The full contract lives in:

```text
docs/GRACE_DODGE_MOTION_RECOVERY_V1.md
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

## Combat footwork and root motion pass

The same ten sword attacks carry lower-body footwork profiles. Their existing movement distance and movement duration remain authoritative, while `CombatFootworkCatalog` reshapes travel into:

```text
Plant → Drive → Settle
```

Each profile identifies a planted foot, stance width, leg path, hip/root accent, steering resistance, and normalized speed curve. Light cuts alternate support, rising attacks load and drive upward, thrusts push rear-to-front, and circular attacks establish a wider pivot.

During profiled grounded attacks, `PlayerCombatFootworkController` supplies collision-aware root velocity through the normal player movement pipeline. Stairs, floor snap, and walls remain physical. Repeated wall obstruction ends remaining attack translation while allowing the visual recovery to finish.

The wire rig replaces ordinary stride motion with authored attack-leg targets during these poses, so Grace's feet no longer keep running beneath a planted sword action. The complete contract lives in:

```text
docs/GRACE_COMBAT_FOOTWORK_ROOT_MOTION_V1.md
```

## Divine Incarnation avatar proxy pass

The wire body now supports reversible avatar identity without replacing the mature shared `Player` node.

`PlayerAvatarManager` preserves the same physical actor, camera, lock-on target, world transform, velocity, health, objective, interaction systems, and progression anchor. A `PlayableAvatarDefinition` swaps the active movement profiles, weapon, spells, and wire presentation as one validated transaction.

The first prototype is Ruvia:

- Fire-only current spell mastery;
- a prototype ember halberd;
- a more aggressive ground profile;
- a forward-biased dodge;
- more committed combat steering;
- a stronger vertical profile;
- scarlet, ember, and gold wire presentation.

In debug builds:

```text
F9 = Ruvia ↔ Grace
```

The active god travels through the same world body. Dismissing the incarnation restores Grace's pre-incarnation kit at the god's current location and with the current shared health pool.

Invalid or partially applied incarnations roll back. A live watchdog also restores Grace if the active weapon, spells, movement profiles, wire identity, actor instance, or camera no longer match the incarnation contract.

The complete architecture and limitations live in:

```text
docs/DIVINE_INCARNATION_AVATAR_PROXY_V0_1.md
```

## Outfit behavior during the wire phase

`GraceWireEquipmentAppearance` preserves outfit feedback without adding costume meshes over the diagnostic skeleton:

- default exploration appearance uses the baseline wire palette;
- Traveler's Coat shifts the rig toward teal, leather, and brass;
- Apprentice Robe shifts the rig toward violet, cyan, and gold;
- Ironweave Jacket shifts the rig toward steel and red.

An active avatar palette takes precedence over outfit coloring. Dismissal or rollback restores the captured mortal outfit presentation.

The actual outfit and god models remain future art work.

## Validation

Focused regressions are:

```text
scenes/tests/grace_animation_smoke_test.tscn
scenes/tests/ground_motion_motor_smoke_test.tscn
scenes/tests/dodge_motion_smoke_test.tscn
scenes/tests/combat_footwork_smoke_test.tscn
scenes/tests/vertical_motion_smoke_test.tscn
scenes/tests/avatar_incarnation_smoke_test.tscn
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
- analog target-speed shaping, acceleration, braking, turning, and reversal;
- coyote time, jump buffering, short-hop release, phase gravity, apex, fall, and landing state;
- impact classification and exact motion-feedback synchronization;
- dodge phase, I-frame, steering, chain, and follow-up behavior;
- authored pose and footwork coverage for every practice-sword attack;
- torso, hand, weapon, root, and leg motion changing across windup and strike;
- attack plant, drive, settle, steering, distance, and wall-block behavior;
- Divine Incarnation definition validity, atomic swap, stable actor and camera ownership;
- transform, velocity, lock-on, health, objective, weapon, spell, and profile preservation;
- Ruvia Fire loadout, halberd rig, avatar palette, dismissal, expiry, and watchdog rollback;
- air and external velocity handoffs;
- animation, grounding, step, vertical, weapon-control, dodge, footwork, avatar, and motion diagnostics.

Expected terminal markers:

```text
GraceAnimationSmokeTest: PASS
GROUND_MOTION_MOTOR_SMOKE_TEST: PASS
DODGE_MOTION_SMOKE_TEST: PASS
COMBAT_FOOTWORK_SMOKE_TEST: PASS
VERTICAL_MOTION_SMOKE_TEST: PASS
AVATAR_INCARNATION_SMOKE_TEST: PASS
```

## Manual review

Open:

```text
scenes/levels/prototypes/prototype_animation_showcase_lab_v1.tscn
```

Review these in order:

1. Stand still and confirm both foot joints rest above the surface.
2. Accelerate, brake, reverse, and run figure eights through the central lane.
3. Use partial controller input and compare low-speed travel with a full stick.
4. Walk up and down every landing step without jumping.
5. In the eastern lane, tap Jump for a short hop and hold Jump for the full arc.
6. Watch Launch, Rising, Apex, Falling, and Landing in the HUD.
7. Walk from a ledge and jump during the coyote window.
8. Press Jump shortly before landing to test the buffered relaunch.
9. Drop from the eastern platform and compare its landing with low-step impacts.
10. Test forward, side, backward, and lock-on backstep dodges in the dodge lane.
11. Chain a second dodge and test dash-strike, cast, and guard exits.
12. Perform every Light and Heavy sword branch in the western footwork lane.
13. Watch the support foot, hip drive, hand path, and blade in that order.
14. Attack into the footwork wall and confirm translation stops without wall shudder.
15. Press `F9` away from the spawn point and confirm Ruvia appears without a teleport or camera change.
16. Compare Ruvia's run, jump, dodge, landing, spells, and ember halberd with Grace.
17. Move elsewhere, change health, and press `F9` again. Grace should return at the current location with current health.
18. Repeat the swap after locomotion, landing, dodge recovery, and a completed attack.
19. Attack and dodge up and down stairs, then immediately jump or land.
20. Climb and mantle the wall, confirming the feet release from ground probing.
21. Press `P` to cycle deterministic poses and `O` to restore live control.
22. Use the existing reset action to restore Grace and reset the course.

## Intentionally unchanged

- player collision dimensions and spatial profile;
- Grace's maximum horizontal movement speed and full-jump launch velocity;
- sword damage, hit geometry, timing, and combo behavior;
- authored sword movement distance and duration;
- dodge balance, spell behavior, and guard balance;
- climbing, swimming, riding, and sustained-flight rules;
- fall damage and landing stagger;
- final Grace and Ruvia character art;
- final halberd moveset, divine techniques, transformation cinematic, sound, rumble, and production VFX.

## Next refinement axis

The diagnostic body now has first-pass contracts for grounding, stairs, ground response, jumping, falling, landing, dodge recovery, sword ownership, combat footwork, and safe avatar identity.

The next coherent sequence is:

1. manually validate Grace ↔ Ruvia transition safety;
2. author Ruvia's dedicated halberd graph, hand paths, and footwork;
3. separate avatar intent from the player input source through control drivers;
4. reuse Ruvia as a player-controlled incarnation, AI ally, boss, and cutscene actor;
5. connect production access to Warlock Mastery and manifestation-resource rules;
6. replace diagnostic wire avatars with skinned character models and final VFX.
