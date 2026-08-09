# Fauna Material Presentation v1

## Goal

Fauna Material Presentation improves the light response of Green Grotto's procedural extinct animals without changing their meshes or ambient behavior.

The current benchmark contains three raptors and one distant sauropod.

## Semantic roles

The Director classifies existing procedural pieces by what they represent rather than by the material resource they happen to reuse.

```text
hide        body, head, legs, tail, neck
feather     raptor crest, body feathers, snout, lower legs, arms
eye         raptor eyes
accent_hide sauropod head and feet
```

This distinction is important because the sauropod accent pieces currently reuse the same base material family used by raptor feathers, but they should not inherit feather-specific presentation behavior.

## Registration

The Green benchmark currently resolves:

```text
3 raptors × 28 meshes = 84
1 sauropod × 19       = 19
                         ---
                         103 total
```

Role counts:

```text
hide        41
feather     51
eye          6
accent_hide  5
```

The Director discovers nodes in the existing `environmental_fauna` group, so runtime-built wildlife can register after the Director enters the tree.

## F7 quality

### Performance

Every registered mesh receives its exact original `StandardMaterial3D` resource.

### Balanced

Hide/feather/accent pieces receive:

- shared procedural normal detail;
- wrapped diffuse lighting;
- modestly reduced roughness;
- raptor feather backlight.

Eyes stay free of procedural normal noise and instead receive a cleaner highlight roughness.

### Cinematic

Cinematic strengthens:

- hide and feather micro-normal response;
- hide/feather/accent highlight structure;
- raptor feather backlight;
- subtle hide/accent backlight;
- eye highlight sharpness and restrained metallic depth.

## Texture-space rule

Fauna detail stays in each procedural mesh's normal object UV coordinates.

World-space triplanar projection is intentionally not used because these actors move. World-anchored texture projection would visibly slide across their bodies while they roam.

## Shared-resource budget

Normal textures are shared by role:

```text
hide
feather
accent_hide
```

Eyes do not need a generated normal map.

Balanced/Cinematic enhanced variants are cached by original material + semantic role + quality and remain under a small bounded variant budget.

## Ownership boundary

Fauna Material Presentation may:

- discover presentation fauna;
- classify their mesh pieces by semantic role;
- swap shared material variants as F7 changes;
- restore exact original material resources in Performance or when disabled.

It must not:

- change fauna geometry;
- change movement or ambient behavior;
- add navigation, collision, perception, or combat state;
- change species identity or gameplay.

## Validation

```text
res://scenes/tests/fauna_material_presentation_director_smoke_test.tscn
```

The regression verifies all 103 mesh registrations, exact role counts, Performance restoration, Balanced/Cinematic material behavior, bounded shared resources, object-UV detail, behavior independence, and unchanged mesh resources.
