# Grace Material Presentation v1

## Goal

Grace is permanently near the center of the camera, so her materials need to participate in the same lighting-quality stack as the environment without granting presentation code gameplay authority.

The original prototype path upgrades Grace's procedural materials while preserving every mesh, animation pivot, gameplay node, and authored base material resource. Production imports may now reuse the same semantic material language through an opt-in surface-level extension.

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

Roles are semantic rather than inferred from the current material resource.

## Prototype mesh path

Canonical director:

```text
scripts/character_presentation/character_material_presentation_director_3d.gd
```

`register_mesh()` remains the tested path for the existing procedural Grace. No existing Green benchmark enrollment is changed by the production-import work.

## Production multi-surface path

A normal skinned GLB may contain several semantic materials on one `MeshInstance3D`. Production Grace therefore does not need to split skin, robe, hair, and eyes into separate scene nodes merely to satisfy the prototype material director.

Opt-in extension:

```text
scripts/character_presentation/character_material_surface_presentation_director_3d.gd
scripts/character_presentation/grace_imported_material_enroller.gd
```

`CharacterMaterialSurfacePresentationDirector3D` inherits the existing quality/material logic and adds `register_surface(mesh, surface_index, role)`.

`GraceImportedMaterialEnroller` scans an imported character and enrolls surfaces conservatively:

1. explicit `character_material_surface_role_<index>` metadata;
2. explicit `character_material_role` metadata;
3. exact, normalized material-name aliases such as `Skin`, `Hair`, `Robe`, `Gold`, or `Leather`;
4. otherwise leave the surface unresolved and report it.

The adapter deliberately avoids fuzzy substring guessing. A strangely named production material should be renamed or explicitly assigned rather than silently classified into the wrong shading role.

## F7 quality contract

Character Material Presentation has no independent hotkey. It follows Lighting Director quality and therefore the existing benchmark presets.

### Performance / BASELINE

Every registered prototype mesh points back to its exact original material resource.

For imported surfaces, Performance restores the exact original surface-override state. If the GLB originally relied on its mesh surface material with no override, the extension restores `null` as the override rather than manufacturing a replacement.

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

Unlike the static environment Material Fidelity system, Grace does **not** use world-space triplanar detail. Her procedural normal textures remain attached through mesh UV coordinates so moving through the world cannot make material detail swim across her body.

## Resource sharing

Enhanced materials are cached by:

```text
role + original material resource + quality tier
```

Meshes or surfaces sharing the same semantic role and base material therefore share enhanced resources. Procedural normal textures are shared by role.

## Ownership boundary

Character Material Presentation may:

- swap material overrides on explicitly enrolled Grace meshes or surfaces;
- generate shared procedural normal textures;
- alter PBR roughness/metallic/backlight/SSS settings by renderer tier.

It must not:

- replace or deform Grace's meshes;
- alter animation or accessory wind;
- alter hitboxes/collision;
- alter gameplay stats or visibility/detection;
- change equipment/loadout semantics;
- dictate how a production character must split its mesh topology;
- become authoritative for the final character's authored textures/material design.

The system is a renderer-quality integration layer, not the final character-art authoring pipeline.

## Validation

```text
res://scenes/tests/grace_material_presentation_smoke_test.tscn
```

The regression verifies the original 27 semantic mesh registrations and quality ladder. It also creates a synthetic three-surface imported character using `Skin`, `Robe`, and an unknown material. Known surfaces enroll into the existing semantic quality pipeline, the unknown surface remains unresolved, Performance restores the original surface arrangement, and geometry remains unchanged.
