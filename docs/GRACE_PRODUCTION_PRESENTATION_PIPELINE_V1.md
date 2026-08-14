# Grace Production Presentation Pipeline V1

## Purpose

Grace can now accept a real skinned character model before the final animation library exists.

The procedural combat rig remains the motion authority and technical reference. A compatible imported skeleton can mirror those semantic poses onto a visible production model. This lets the project evaluate silhouette, topology, skinning, materials, weapon alignment, and deformation immediately instead of waiting for final authored clips.

```text
Gameplay and weapon controllers
            |
            v
Hidden procedural Grace skeleton
            |
            v
GraceSkeletonPoseMirror
            |
            v
Visible imported Grace skeleton and skin
```

The imported model does not own movement speed, attack timing, hitboxes, targeting, combo logic, or traversal physics.

## Stable production boundary

The production skeleton contract lives at:

```text
res://scripts/visuals/grace_production_skeleton_contract.gd
```

The required production semantics are the current complete 23-bone calibration set:

```text
root
pelvis
spine_01
spine_02
chest
neck
head
clavicle_l
upper_arm_l
forearm_l
hand_l
clavicle_r
upper_arm_r
forearm_r
hand_r
thigh_l
shin_l
foot_l
toe_l
thigh_r
shin_r
foot_r
toe_r
```

Extra bones are encouraged. Finger, face, twist, hair, cloth, robe, accessory, and secondary-motion bones are outside the required gameplay contract and remain available to the production asset.

The contract also validates:

- Semantic coverage and hierarchy
- Non-collapsed rest transforms
- Approximate left/right limb symmetry
- Accepted character rest scale
- Virtual sockets for the weapon hand, support hand, head aim, feet, back mount, and hip mount

## Runtime presentation controller

The combat player now contains:

```text
GraceProductionPresentation
```

Scene:

```text
res://scenes/actors/player/grace_production_presentation_controller.tscn
```

The controller supports four modes:

1. **Auto**
   - Uses the imported model when it is safe to pose-mirror.
   - Falls back to the procedural Grace otherwise.

2. **Procedural Only**
   - Keeps the current technical model visible.

3. **Imported Preview**
   - Shows a mirror-compatible imported model even if it is missing production-preferred bones such as toes or clavicles.

4. **Imported Active**
   - Requires the complete production contract.

No imported scene is assigned yet, so the live player behaves exactly as before.

## Pose mirroring

The bridge is:

```text
res://scripts/visuals/grace_skeleton_pose_mirror.gd
```

It copies local pose rotation by semantic role rather than by raw bone index. Root and pelvis translation can be copied separately and scaled for a target rig with slightly different proportions.

For pose mirroring to behave correctly, Godot's humanoid import and rest-fixing tools must normalize the imported skeleton to a compatible rest orientation. Matching names alone is not enough if the local bone axes are unrelated.

The source proxy continues processing while hidden. The imported model becomes visible, and its right-hand pose becomes authoritative for the weapon socket. This prevents a differently proportioned model from holding the weapon at the procedural hand position.

## First imported asset workflow

1. Build or acquire a simple skinned Grace candidate.
2. Export it as GLB from Blender.
3. Import the scene in Godot.
4. Use Advanced Import Settings and `SkeletonProfileHumanoid` to map and normalize the skeleton.
5. Save the imported scene as a reusable inherited or wrapper scene.
6. Assign that scene to `imported_character_scene` on `GraceProductionPresentation`.
7. Start in **Imported Preview**.
8. Inspect the controller debug data:
   - `mirror_ready`
   - `production_ready`
   - `missing_production`
   - `weapon_socket_error`
9. Test the complete dojo movement and combat sequence.
10. Promote to **Auto** or **Imported Active** only after the asset passes the production checklist.

## Acceptance sequence

Every Grace model candidate must survive:

- Idle, run, start, stop, jump, fall, and landing silhouettes
- Fast direction changes and dodges
- Staff two-handed grip, returning throw, Bastion, and pole vault
- Axe side hews, edge-first overheads, charge Heavy, aerial attacks, and counter guard
- One-handed and two-handed weapon socket alignment
- Deep crouches and wide shoulder motion
- Feet contacting stairs and uneven floors
- Camera-close views without exposed mesh gaps
- Extreme poses without catastrophic shoulder, elbow, wrist, hip, or knee collapse

## Promotion stages

The auditor now reports these stages:

```text
blocked_skeleton
skeleton_only
pose_mirror_candidate
production_model_candidate
locomotion_candidate
sword_candidate
```

A `production_model_candidate` is already useful. It has visible geometry and a complete production skeleton, and it can inherit the procedural motion library even before authored animations exist.

## Animation migration later

The pose mirror is a bridge, not the final animation architecture.

The intended migration remains:

```text
procedural pose mirror
        ->
imported locomotion clips
        ->
weapon-class attack clips
        ->
AnimationTree blending and one-shots
        +
procedural IK, aim, foot placement, weapon physics, and secondary motion
```

Each imported clip can replace one semantic layer without changing gameplay or forcing a whole-character animation rewrite.

## Regression

Scene:

```text
res://scenes/tests/grace_production_presentation_smoke_test.tscn
```

The test verifies:

- The frozen 23-bone production contract
- Common Godot humanoid aliases
- Rest scale and symmetry
- Semantic pose mirroring
- Pelvis translation mirroring
- Procedural fallback when no imported model is assigned
- Live combat-player preload with the presentation bridge installed
