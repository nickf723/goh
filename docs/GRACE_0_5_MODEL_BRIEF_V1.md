# Grace 0.5 Model Brief V1

## Goal

Create the first real skinned Grace model that can replace the visible procedural mannequin during normal play without pretending to be the final cinematic asset.

Grace 0.5 must be attractive, readable, modular, deformation-safe, and easy to revise. Silhouette and movement matter more than pores, embroidery, or dense facial detail.

## Character stage

This model represents early-journey Grace.

- Young adolescent silhouette
- Small, athletic, and agile rather than tiny or toddler-like
- Stylized heroic proportions rather than strict anatomical realism
- Curious, kind, slightly unruly visual energy
- Capable of carrying oversized weapons without becoming visually top-heavy

The approved combat silhouette from the current skeletal proxy remains the scale reference. Do not shrink the model simply to communicate age.

## Style target

The character should sit between saturated adventure fantasy and grounded dark-fantasy material response.

- Simple, graphic major forms
- Restrained surface detail
- Strong readable silhouette at gameplay distance
- Softly stylized face
- Chunky hair masses rather than thousands of strands
- Cloth that feels practical and traveled-in
- Materials with believable roughness and weight
- No hyperreal skin, doll-like gloss, or noisy micro-detail

## Starting outfit

Grace's first outfit is an exploration robe assembled by someone who values control and practicality over self-expression.

Required visual components:

- Short layered travel robe or tunic
- Split lower panels for running, jumping, and pole-vault poses
- Contrasting waist sash
- Simple fitted underlayer at arms and legs
- Durable boots
- Small leather fasteners and utility loops
- Modest gold or brass accent hardware
- No visible modern electronics

The outfit should read clearly from front, side, and back. Avoid one large rigid skirt shell that collapses during crouches or clips through both legs during combat.

## Silhouette priorities

1. Recognizable hair shape
2. Clear head, neck, shoulder, and robe separation
3. Narrow waist with readable sash
4. Lower robe panels that frame rather than hide the legs
5. Boots large enough to sell planted combat poses
6. Hands large and simple enough to read weapon grips
7. Back silhouette that leaves room for future weapon and equipment mounts

## Modular pieces

Preferred scene organization:

```text
GraceModelRoot
  Skeleton3D
  BodyMesh
  HeadMesh
  HairBase
  HairBack
  RobeUpper
  RobeLowerPanels
  Sash
  Boots
  GlovesOrWraps
  OptionalAccessories
```

Body, hair, robe, and accessories should remain replaceable without changing the skeleton or gameplay scene.

## Geometry target

These are production-proxy targets, not absolute engine limits.

- Approximately 30,000 to 50,000 visible triangles for the complete hero model
- One subdivision-free gameplay mesh
- Clean deformation loops at shoulders, elbows, wrists, hips, knees, ankles, neck, and jaw
- Additional geometry reserved for face silhouette, hands, robe edges, and hair silhouette
- No hidden duplicate bodies unless required for outfit swapping
- No non-manifold geometry
- No uncontrolled internal intersections
- Consistent normals and applied transforms before export

A lower-detail model with clean deformation is preferred over a denser generated mesh with tangled edge flow.

## Material slots

Target no more than six primary material families:

```text
Skin
RobeCloth
SashAccent
LeatherAndBoots
HairAndBrows
MetalAndEyes
```

The first pass may use 2K texture sets. Materials should remain separable so the game can recolor outfits, apply wetness, poison, elemental light, damage, or story-state changes later.

## Required skeleton

The canonical contract is defined in:

```text
res://scripts/visuals/grace_production_skeleton_contract.gd
```

The model must include all 23 production semantics. Additional bones are welcome.

Recommended extras:

- Upper-arm and forearm twist bones
- Thigh and calf twist bones
- Three simple finger chains per hand or grouped finger controls
- Jaw
- Eye aim bones
- Two to four hair chains
- Two to six robe or sash secondary-motion bones

These extras must not interrupt the required parent chains.

## Skinning requirements

The model must pass these poses without severe collapse:

- Arms straight overhead with both hands close together
- Wide two-handed staff grip
- Cross-body axe guard
- Deep overhead axe windup
- Full crouch
- One knee raised above hip height
- Forward aerial extension
- Staff pole-vault compression
- Staff vault launch
- Axe aerial crash
- Dodge tuck
- Torso twist beyond 45 degrees

Watch especially for:

- Shoulder volume disappearing
- Elbow candy-wrapper twisting
- Wrist collapse around two-handed grips
- Robe panels entering the pelvis
- Knee spikes
- Boot tops cutting into the calf
- Hair entering the shoulders or weapon path

## Face and hands

Grace 0.5 does not require a final facial rig.

Required now:

- Clean neutral expression
- Readable eyes and brows
- Mouth topology capable of a later jaw or basic expression pass
- Simplified but believable hands
- Thumb placement that survives weapon grips

Not required yet:

- Lip sync
- Wrinkle maps
- Individual teeth
- Full finger animation library
- Cinematic eye shader

## AI-assisted asset policy

AI generation may be used for:

- Multi-view concept exploration
- Rough base-mesh candidates
- Hair and outfit shape ideation
- Texture drafts
- Material-mask drafts
- Background accessory variants

AI output is not accepted directly when it has:

- Unstable topology
- Asymmetric limbs without design intent
- Fused fingers
- Inconsistent front and back views
- Clothing baked inseparably into the body
- Unusable UVs
- Unpredictable skeleton axes
- Weight painting that fails the required combat poses

The preferred pipeline is:

```text
controlled concept sheet
  -> generated or purchased base candidate
  -> silhouette correction
  -> retopology
  -> UV and material cleanup
  -> canonical skeleton
  -> deliberate skinning
  -> Godot import and pose-mirror test
```

## Export package

Preferred first delivery:

```text
art/characters/grace/grace_0_5.blend
art/characters/grace/grace_0_5.glb
art/characters/grace/textures/
scenes/actors/player/grace_0_5_imported.tscn
```

Export expectations:

- Metric scale
- Applied object transforms
- One stable skeleton
- Consistent forward axis
- Meshes skinned to the production skeleton
- No gameplay scripts inside the GLB
- No root-motion assumptions
- Neutral reference rest preserved

## First acceptance test

The first successful import does not need authored animation clips.

Assign the imported wrapper scene to `GraceProductionPresentation`, choose **Imported Preview**, and let `GraceSkeletonPoseMirror` drive the model through the existing dojo.

The candidate passes Grace 0.5 when:

- It survives Staff and Axe movement without catastrophic deformation
- The weapon remains in the visible right hand
- Two-handed poses look physically plausible
- Feet remain close to the approved ground plane
- The silhouette reads at normal camera distance
- The materials feel coherent under the Church and dojo lighting
- The procedural fallback can be restored instantly
