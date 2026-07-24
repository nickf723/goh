# Grace Animation and Presentation v1 — Manual Test

## Purpose

Verify the first evolved Grace presentation rig without changing authoritative movement, collision, attack timing, damage timing, or save state.

The same `GraceVisualV1` wrapper remains in every player scene. Its formerly flat primitive pieces are now arranged beneath lightweight articulation pivots and animated procedurally from the existing gameplay state.

## Recommended scenes

- `res://scenes/levels/prototypes/prototype_combat_survival_trial_v1.tscn`
- `res://scenes/levels/prototypes/prototype_aerial_traversal_lab_v1.tscn`
- `res://scenes/levels/prototypes/prototype_weapon_combat_arena_v1.tscn`

## Visual route

1. Stand still and confirm Grace breathes subtly instead of bobbing as one rigid piece.
2. Walk forward, backward, and sideways. Confirm the boots stride, arms counter-swing, torso turns slightly, and the robe remains the stable visual center.
3. Jump and fall. Confirm the arms and legs use distinct ascent and descent silhouettes.
4. Dodge in several directions. Confirm Grace compresses into the dodge and leans toward lateral movement without changing the gameplay collision.
5. Hold Guard. Confirm the torso lowers and both arms form a compact defensive silhouette.
6. Perform Light and Heavy weapon attacks. Confirm the torso and arms join the existing weapon trajectory; Heavy attacks should read with slightly more commitment.
7. Cast a spell. Confirm Grace raises the casting side and counterbalances with the other arm.
8. Use a Healing Flask. Confirm the right arm lifts toward her face during the committed item-use window.
9. Let an enemy hit Grace. Confirm the model recoils during stagger.
10. Let Grace be defeated. Confirm the visual falls while the authoritative player root remains controlled by the existing death system.
11. Test Flight. Confirm the arms open and the body adopts a forward aerial pose.
12. Watch the violet sash tail and front hair locks during movement and actions. Confirm they follow with secondary sway rather than remaining welded to the torso.

## Model evolution

- Shoulder and leg pivots provide readable limb animation while preserving the replacement-ready wrapper.
- Head, torso, sash tail, and front hair locks animate independently.
- Cuffs, collar, sash knot, boot soles, brows, mouth, and eye highlights improve readability at normal camera distance.
- Existing root-level head, hand, chest, and feet marker paths remain stable.
- The weapon hand anchor follows the animated right hand, while the weapon controller continues to own attack trajectories and hit timing.

## Automation

Run:

`res://scenes/tests/grace_animation_presentation_smoke_test.tscn`

The smoke test verifies the articulated hierarchy, stable VFX marker paths, action-state pose resolution, and defeat presentation state.

## Known limits

- This is a transform-driven prototype rig, not the final skinned production model.
- The robe is a rigid stylized volume; it does not yet deform around the legs.
- Hands do not use fingers, inverse kinematics, or per-weapon grip poses.
- Foot planting, terrain-aware ankle placement, facial expressions, animation clips, and authored transitions remain future upgrades.
- Root motion remains intentionally disabled: gameplay movement stays authoritative.
