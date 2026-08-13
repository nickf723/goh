# Grace Skeletal Animation Pipeline v1

## Goal

This pass replaces the Arsenal Dojo's visible procedural-pivot mannequin with a real articulated `Skeleton3D` presentation proxy while preserving the gameplay feel that survived recorded playtesting.

Primary playtest scene:

```text
res://scenes/levels/prototypes/prototype_weapon_arsenal_dojo_v1.tscn
```

The purpose is **not** to declare the generated proxy body final art. The purpose is to make the character-animation contract production-shaped before a Blender / GLB Grace is imported.

## Architecture boundary

Gameplay remains authoritative:

```text
movement input
→ GroundMotionMotor / DodgeMotionController / CombatFootworkController
→ WeaponController attack timing, targeting, hit frames, cancels, and displacement
→ character presentation state
→ Skeleton3D pose
→ hand socket
→ existing weapon presentation
```

The skeleton does not decide whether an attack hits, how far Grace is allowed to travel, or when damage occurs.

## Skeletal proxy

Scene:

```text
res://scenes/actors/player/grace_humanoid_skeletal_proxy_v1.tscn
```

Controller:

```text
res://scripts/visuals/grace_humanoid_skeletal_proxy_v1.gd
```

The proxy builds a 23-bone hierarchy:

```text
root
└── pelvis
    ├── spine_01
    │   └── spine_02
    │       └── chest
    │           ├── neck → head
    │           ├── clavicle_l → upper_arm_l → forearm_l → hand_l
    │           └── clavicle_r → upper_arm_r → forearm_r → hand_r
    ├── thigh_l → shin_l → foot_l → toe_l
    └── thigh_r → shin_r → foot_r → toe_r
```

The disposable proxy meshes are generated from those bone transforms. Geometry is therefore downstream of the rig rather than being the rig itself.

## First animation vocabulary

The v1 bone driver resolves:

- idle breathing and weight shift;
- agile locomotion with pelvis counter-rotation, alternating arm swing, knee bend, foot flex, braking, turning, and reversal accents;
- jump and fall poses;
- directional dodge compression and recovery;
- hit recoil;
- Sword cuts with pelvis-to-spine-to-shoulder sequencing;
- Sword thrusts;
- overhead Heavy attacks;
- rising / launcher attacks;
- broad / spinning cuts;
- explicit windup → contact → follow-through → recovery pose stages;
- target-facing chest / head commitment from the existing engagement target.

The first objective is **Sword quality**, not complete weapon coverage.

## Weapon socket contract

The skeleton owns the right-hand pose but does not own weapon gameplay.

`hand_r` drives:

```text
Player/WeaponController/HandAnchor
```

The existing WeaponController continues to own:

- the equipped weapon;
- attack graph and timing;
- weapon-specific runtime rigs;
- hit geometry;
- trails;
- infusion presentation;
- impact logic.

During this migration `WeaponRecoveryPresenter` normalizes the HandAnchor scale after the skeletal socket update, so Grace may remain visually 0.93 scale without shrinking authored weapon proportions.

This is the intended future imported-model boundary:

```text
imported humanoid skeleton hand socket
→ existing WeaponController HandAnchor
```

## Agile Grace preserved

The dojo keeps the accepted agile calibration:

- slightly smaller presentation;
- modestly higher top speed;
- stronger acceleration, turning, reversal, and braking;
- shorter / quicker dodge cadence.

`GraceAgilityCalibration` now prefers `GraceSkeletalVisualV1` when available and falls back to the legacy visual elsewhere.

The collision capsule remains unchanged during this visual calibration.

## Legacy migration policy

`GraceVisualV1` remains instantiated but hidden in `player_combat_v2.tscn`.

This is deliberate during v1:

- existing procedural presentation remains available as a reference / rollback;
- old weapon-pivot presentation can continue supplying authored weapon arcs while the skeleton supplies hand and body motion;
- the new skeletal rig can be evaluated without deleting canonical traversal presentation used by the rest of the game.

Once the skeletal path survives playtesting across locomotion, Sword, dodge, jump / landing, casting, and at least one heavy weapon, the legacy visual can be retired from the combat-test player and the skeletal adapter can be promoted toward canonical Grace.

## Final asset replacement contract

A future Blender / GLB Grace should preserve or map these functional bones:

```text
pelvis
spine_01
spine_02
chest
neck
head
clavicle_l / clavicle_r
upper_arm_l / upper_arm_r
forearm_l / forearm_r
hand_l / hand_r
thigh_l / thigh_r
shin_l / shin_r
foot_l / foot_r
toe_l / toe_r
```

The production mesh may add twist bones, fingers, face bones, cloth bones, hair bones, weapon-specific support sockets, and corrective deformation bones without changing gameplay.

The imported asset should expose a reliable right-hand weapon socket and enough lower-body articulation for foot planting.

## Manual calibration sequence

Use Sword and the center target.

```text
idle
→ run toward target
→ hard stop
→ Light
→ Light
→ Heavy
→ dodge sideways
→ re-engage
→ Heavy
→ run away
```

Then deliberately inspect:

1. **Leg generation** — does the strike visibly begin from the stance rather than the shoulder alone?
2. **Pelvis / spine chain** — does rotation travel upward through the body?
3. **Elbow** — does the sword arm extend and recover rather than behave as one rigid stick?
4. **Weapon grip** — does the weapon remain attached to the animated right hand throughout the attack?
5. **Follow-through** — does contact continue into an overshoot before braking?
6. **Target commitment** — do chest and head remain aware of the enemy during the strike?
7. **Locomotion** — do knees and feet make the agile movement profile easier to read?
8. **Dodge** — does the body compress and redirect rather than simply translate?

## Automated contract

The existing combat-feel regression now verifies:

- `GraceSkeletalVisualV1` is active;
- legacy `GraceVisualV1` is hidden;
- the proxy owns a `Skeleton3D`;
- bone count is at least 23;
- pelvis, multi-bone spine, elbows, knees, and right weapon hand exist;
- the existing HandAnchor follows the skeletal right-hand socket;
- agility calibration targets the skeletal visual;
- Sword engagement drives the skeletal attack state.

Test scene:

```text
res://scenes/tests/grace_combat_feel_pass_01_smoke_test.tscn
```

## Known limitations

- The generated geometry is a calibration mannequin, not final character art.
- The v1 motion library is bone-driven in Godot rather than imported authored clips.
- True foot IK is not yet implemented.
- Support-hand IK for two-handed weapons is not yet implemented on the skeletal proxy.
- Casting, climbing, swimming, and full weapon-class animation coverage still use the older presentation outside this dojo experiment.
- Facial animation remains minimal in the proxy.

## Next animation work

If Sword immediately benefits from the articulated proxy, refine in this order:

```text
foot planting / stop-turn quality
→ Sword hand and wrist alignment
→ support-hand IK contract
→ dodge and landing polish
→ imported animation / retargeting adapter
→ Hammer as heavy-weapon contrast
→ casting upper-body layer
→ promote skeletal presentation to canonical Grace
```

Do not author all sixteen weapon animation families before the Sword calibration sequence feels convincing.
