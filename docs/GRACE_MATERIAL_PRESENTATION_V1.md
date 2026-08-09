# Grace Material Presentation v1

## Goal

Grace is permanently near the center of the camera, so her procedural materials need to participate in the same lighting-quality stack as the environment without requiring a remodeled character.

Character Material Presentation upgrades the existing Grace material language while preserving every mesh, animation pivot, gameplay node, and authored base material resource.

## Semantic roles

The Green benchmark registers 27 Grace meshes into eight roles:

```text
skin     Head + two hands
hair     hair mass + two locks + two brows
eye      two eyes
robe     skirt + torso + two arms
sash     waist sash + sash tail + hair ribbon
gold     collar + brooch + knot + two cuffs
leather  two boots + two soles
mouth    mouth
```

Roles are assigned from semantic node identity, not inferred from the current material resource. This matters because a few stylized placeholder parts intentionally reuse existing dark materials.

## F7 quality contract

Character Material Presentation has no independent hotkey. It follows Lighting Director quality and therefore the existing F9 benchmark presets.

### Performance / BASELINE

Every registered mesh points back to the exact original material resource from `grace_visual_v1.tscn`.

No replacement mesh or material approximation is used.

### Balanced

Balanced creates shared material variants with:

- restrained procedural normal breakup;
- cheaper skin and hair backlight;
- less perfectly matte robe/sash/leather response;
- preserved semantic color palette;
- no skin subsurface scattering.

### Cinematic / HERO

Cinematic retains the Balanced improvements and adds:

- restrained skin subsurface scattering;
- skin transmittance for warm rim/backlight;
- richer skin highlight response;
- slightly sharper hair response;
- sharper gold specular response;
- stronger cloth/leather microdetail.

## Texture coordinates

Unlike the static environment Material Fidelity system, Grace does **not** use world-space triplanar detail. Her procedural normal textures remain attached through the mesh's UV coordinates so moving through the world cannot make material detail swim across her body.

## Resource sharing

Enhanced materials are cached by:

```text
role + original material resource + quality tier
```

Meshes sharing the same semantic role and base material therefore share the same enhanced resource. Procedural normal textures are shared by role.

## Ownership boundary

Character Material Presentation may:

- swap `material_override` resources on explicitly enrolled Grace meshes;
- generate shared procedural normal textures;
- alter PBR roughness/metallic/backlight/SSS settings by renderer tier.

It must not:

- replace or deform Grace's meshes;
- alter animation or accessory wind;
- alter hitboxes/collision;
- alter gameplay stats or visibility/detection;
- change equipment/loadout semantics;
- become the final production character-art pipeline.

## Validation

```text
res://scenes/tests/grace_material_presentation_smoke_test.tscn
```

The regression verifies:

- exactly 27 semantic Grace mesh registrations;
- expected role counts;
- Performance restores exact original material objects;
- Balanced adds micro-normal/backlight without SSS;
- Cinematic adds restrained skin SSS/transmittance and richer PBR response;
- mesh resources remain identical through all quality changes;
- shared variant/texture budgets remain bounded;
- no gameplay authority is introduced.
