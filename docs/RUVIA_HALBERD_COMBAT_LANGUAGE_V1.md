# Ruvia Halberd Combat Language v1

## Purpose

Ruvia's Divine Incarnation now uses a dedicated combat graph rather than borrowing the training spear forms.

The physical rule is:

```text
Rear hand drives force
Front hand guides the shaft
Hips redirect the weapon
Feet absorb the orbit
Blade arrives last
```

The right hand remains the weapon anchor. The left hand is solved against an authored support-grip point on the live halberd rig, allowing it to slide, brace, and redirect the shaft during every attack.

## Attack graph

### Light sequence

```text
Cinder Sweep
      ↓
Backdraft Return
      ↓
Haft Check
      ↓
Rising Brand
      ↓
Ember Wheel
```

- **Cinder Sweep** establishes broad halberd range.
- **Backdraft Return** uses the weapon's returning momentum rather than resetting to neutral.
- **Haft Check** strikes with the shaft when an enemy has entered inside the blade's ideal range.
- **Rising Brand** drives upward through the legs and can launch.
- **Ember Wheel** is the committed rotational Light finisher.

### Heavy branches

```text
Neutral Heavy       Furnace Drop
After Cinder Sweep  Scorching Thrust
After Backdraft     Reaping Hook
After Haft Check    Wildfire Cleave
After Rising Brand  Solar Descent
```

- **Furnace Drop** is a planted overhead guard-breaking form.
- **Scorching Thrust** slides the guide hand rearward during preparation, then forward along the shaft during the committed thrust.
- **Reaping Hook** uses the back hook and low knockback to retain a pulling identity.
- **Wildfire Cleave** is a broad anti-group branch.
- **Solar Descent** is the first divine-feeling grounded finisher, with stronger Burning and upward force.

## Two-handed performance

The upper-body pose catalog is owned by:

```text
scripts/weapons/ruvia_halberd_pose_catalog.gd
scripts/weapons/weapon_pose_catalog_router.gd
```

Every attack contains authored:

- torso and head counter-rotation;
- rear-arm drive;
- guide-arm positioning;
- right-hand travel and wrist control;
- support-grip position and orientation along the shaft;
- weapon-local motion share;
- support-hand release through recovery.

`PlayerWeaponControlAnimator` applies the weapon sample first, then resolves the support hand against the transformed rig. The wire renderer resamples after that lock so both hands, elbows, shaft, and weapon remain in agreement during the same frame.

The dedicated pose catalog coexists with Grace's sword poses through `WeaponPoseCatalogRouter`. Grace's existing sword behavior is unchanged.

## Footwork

Ruvia retains her avatar-specific `CombatFootworkProfile`, which provides lower steering and greater commitment than Grace.

The ten halberd attacks reuse the proven Plant, Drive, and Settle shapes already authored for the shared humanoid lower body:

- alternating cut plants;
- compact thrust plant;
- rising drive;
- circular pivot;
- overhead two-foot plant;
- committed thrust;
- heavy rising drive;
- wide cleave plant;
- orbit-finisher pivot.

This is intentional reuse of the shared movement contract, not a return to spear behavior. Attack geometry, graph structure, upper-body control, support-hand motion, Fire identity, names, timing, and weapon presentation are all Ruvia-specific.

## Payload identity

Blade forms use the Ember Halberd's Fire payload and apply Burning.

**Haft Check** uses:

```text
data/damage_payloads/ruvia_halberd_haft_payload.tres
```

The runtime rig removes inherited Fire and Burning metadata from that attack, preserving a physical close-control option.

**Reaping Hook** gains pull identity and reduced outward knockback.

**Solar Descent** guarantees stronger Burning duration and intensity, additional upward force, and divine-finisher tags.

No Heat meter, Divine Art meter, or new resource loop is introduced in v1.

## Attack-aware weapon rig

The existing procedural weapon scene now uses:

```text
scripts/weapons/ruvia_ember_halberd_rig.gd
```

It provides:

- duplicated per-instance materials;
- blade and accent emission that rises through attack commitment;
- stronger finisher emission;
- support-grip reference markers;
- payload specialization;
- attack, phase, hit, and material diagnostics.

The presentation is still a replacement-ready prototype rather than final weapon art or Fire VFX.

## Automated validation

Run in Godot:

```text
scenes/tests/ruvia_halberd_combat_smoke_test.tscn
```

Expected Output-panel marker:

```text
RUVIA_HALBERD_COMBAT_SMOKE_TEST: PASS
```

The regression checks:

- a valid ten-attack graph;
- all attack names and graph IDs;
- one bespoke two-handed pose per attack;
- valid shared footwork for every form;
- finite startup, active, and recovery samples;
- visible support-hand sliding during Scorching Thrust;
- Fire and Burning on blade forms;
- physical neutral behavior on Haft Check;
- stronger Solar Descent Fire metadata;
- live Ruvia incarnation and runtime rig installation;
- support-hand shaft locking for all ten attacks;
- finite wire poses and readable hand spacing.

## Manual review

Open:

```text
scenes/levels/prototypes/prototype_animation_showcase_lab_v1.tscn
```

Then:

1. Press `F9` to incarnate Ruvia.
2. Perform the complete five-Light sequence slowly, watching the rear hand, guide hand, hips, feet, and blade in that order.
3. Repeat the sequence rapidly to test buffering and recovery flow.
4. Use neutral Heavy to test Furnace Drop.
5. Press Heavy after Light 1 to test Scorching Thrust. Watch the left hand slide along the shaft rather than orbit freely.
6. Press Heavy after Light 2 to test Reaping Hook.
7. Press Heavy after Light 3 to test Wildfire Cleave.
8. Press Heavy after Light 4 to test Solar Descent.
9. Begin each form while moving, strafing, locked on, and near the footwork wall.
10. Attack up and down the stairs.
11. Compare Haft Check at close range with the blade attacks at the halberd's ideal distance.
12. Confirm Ember Wheel and Solar Descent feel committed without becoming unresponsive.
13. Press `F9` to return to Grace and confirm her sword performance remains unchanged.

## Deliberate boundaries

- Damage and timing are first-pass values awaiting playtest.
- The lower-body pose shapes are shared humanoid footwork profiles rather than a second Ruvia-only root-motion framework.
- Dash and aerial techniques still derive from the shared context-technique system.
- The current halberd and Ruvia body remain diagnostic procedural art.
- Final Fire trails, impact effects, sound, rumble, camera language, and hit reactions are deferred.
- No Heat gauge, Divine Art, patron dialogue, autonomous Ruvia AI, or transformation cinematic is included.
