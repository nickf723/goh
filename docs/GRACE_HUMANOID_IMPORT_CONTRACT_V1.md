# Grace Humanoid Import Contract V1

## Goal

Replace the procedural skeletal proxy with a production Blender/GLB Grace without changing gameplay, combat timing, targeting, movement, weapon ownership, or the Light/Heavy combo grammar.

Godot owns skeleton retargeting. Grace gameplay code owns semantic meaning.

```text
Blender / GLB anatomy
        ↓
Godot BoneMap + SkeletonProfileHumanoid
        ↓
GraceHumanoidRigContract semantic map
        ↓
Grace presentation adapters / sockets / IK
        ↓
existing movement + combat gameplay
```

Do not build a parallel custom retargeter unless Godot's importer demonstrably cannot support a required production asset.

## Godot import baseline

For a production humanoid character:

1. Export a skinned humanoid as glTF/GLB.
2. Open Godot's Advanced Import Settings for the 3D scene.
3. Select the imported `Skeleton3D`.
4. Create a `BoneMap` using the built-in `SkeletonProfileHumanoid` profile.
5. Verify required bones map correctly. Auto-mapping is useful, but manually correct anything ambiguous.
6. Prefer common English bone names in Blender when possible so auto-mapping is predictable.
7. Enable mapped bone renaming when the character should participate in shared animation libraries.
8. Use the rest-fixing options deliberately. Shared animation needs compatible bone rests, not merely matching names.
9. For a normal humanoid sharing locomotion/combat clips, target a clean T-pose/reference-rest compatible with the humanoid profile.
10. Keep animated accessories, cloth, hair, face bones, and other unmapped extras outside Grace's required semantic contract. They may remain on the imported rig.

The exact import settings are asset-dependent. Do not blindly apply silhouette/rest fixes to every model without checking the imported result.

## Grace semantic contract

Canonical semantic owner:

```text
res://scripts/visuals/grace_humanoid_rig_contract.gd
```

Gameplay/presentation code should ask for semantic roles rather than assume a DCC-specific bone name.

Required roles:

```text
pelvis
spine_01
chest
neck
head
upper_arm_l
forearm_l
hand_l
upper_arm_r
forearm_r
hand_r
thigh_l
shin_l
foot_l
thigh_r
shin_r
foot_r
```

Optional but preferred:

```text
root
spine_02
clavicle_l
clavicle_r
toe_l
toe_r
```

The contract accepts both the current prototype names and common/Godot humanoid names. Examples:

```text
pelvis       ← pelvis / Hips
upper_arm_l  ← upper_arm_l / LeftUpperArm
forearm_l    ← forearm_l / LeftLowerArm
hand_r       ← hand_r / RightHand
thigh_r      ← thigh_r / RightUpperLeg
foot_l       ← foot_l / LeftFoot
```

Name matching is normalized for case, underscores, spaces, dashes, and a common `mixamorig:` prefix.

## Production socket semantics

These roles are part of the character/weapon boundary:

```text
hand_r  = primary weapon hand
hand_l  = support hand / off-hand
head    = gaze, aim, and future facial/head tracking anchor
foot_l  = left foot planting / IK anchor
foot_r  = right foot planting / IK anchor
```

The actual held weapon remains owned by `WeaponController`.

Two-handed weapon presentation remains:

```text
WeaponController right-hand socket
        +
WeaponSupportGripContract
        +
left-arm TwoBoneIK3D
```

Imported weapon models may expose an authored child marker named `SupportGrip`. Prototype weapons continue using calibrated fallback grip positions.

## What a final Grace GLB must not own

The imported character asset must not become authoritative for:

- movement speed or acceleration;
- dodge distance/timing;
- attack hit timing;
- attack range or hit geometry;
- targeting or attack steering;
- Light/Heavy combo graph;
- damage, stance, reactions, or hit stop;
- weapon ownership;
- spell logic.

Animation expresses those gameplay contracts. It does not redefine them.

## Animation asset strategy

Prefer reusable humanoid clips when possible:

```text
idle / locomotion / stop / turn
jump / fall / land
dodge
hit / stagger
weapon-class attack clips
```

The first production animation replacement should remain Sword-first because Sword is the calibration class for the current combat feel.

Use additive or procedural layers for things that should remain contextual:

- target-facing chest/head bias;
- support-hand IK;
- foot IK;
- aim offsets;
- small hit reactions;
- breathing / secondary motion.

Do not bake target-specific homing or exact world displacement into every attack animation.

## Current compatibility baseline

The current procedural Grace skeleton is intentionally treated as a reference rig for the semantic contract.

Existing regression:

```text
res://scenes/tests/grace_skeletal_grounding_smoke_test.tscn
```

It validates both:

1. the live 23-bone procedural Grace skeleton; and
2. a synthetic skeleton using Godot humanoid-profile bone names.

Both must resolve the same Grace semantic roles.

## Asset acceptance checklist

Before replacing the active proxy with an imported Grace asset, verify:

- `Skeleton3D` is found and stable;
- all required Grace semantics map;
- arm, leg, and spine hierarchy is valid;
- right hand produces a stable weapon socket;
- left hand can reach two-handed support grips without pathological elbow flips;
- feet align with the visual ground plane;
- character height matches the approved Grace silhouette;
- shared locomotion clips do not visibly foot-slide at the approved agile movement speeds;
- Sword Light/Heavy calibration sequence remains readable;
- dodge and aerial animations preserve gameplay timing;
- unmapped hair/cloth/face bones survive import as intended.

## Promotion rule

The procedural proxy remains the active calibration rig until an imported character passes the same movement/combat sequence cleanly.

Do not delete the proxy on the first successful import. Keep it available as a technical reference until the imported presentation has survived locomotion, Sword, two-handed grip, aerial, hit-reaction, and spellcasting tests.
