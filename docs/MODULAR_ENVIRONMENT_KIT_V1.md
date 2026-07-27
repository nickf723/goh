# Modular Environment and Prop Kit v1

The modular environment kit is the first production-facing bridge between procedural prototype architecture and future imported art. It provides reusable Godot scenes with shared materials, matched collision, consistent scale, stable pivots, and a dedicated benchmark set.

## Scope

The v1 **Weathered Cloister** kit contains:

```text
weathered_stone_floor_4m
weathered_stone_wall_4m
weathered_stone_arch_4m
weathered_stone_stairs_4m
weathered_stone_pillar_3m
weathered_timber_frame_4m
weathered_iron_gate_3m
weathered_stone_pedestal
weathered_crate
weathered_barrel
weathered_wall_sconce
weathered_water_channel_4m
```

Each asset is a reusable `.tscn` under `scenes/environment/modular/`. The catalog at `scripts/environment/modular_environment_catalog.gd` is the canonical lookup and validation owner.

## Visual target

This is still stylized low-poly prototype art, but it is no longer raw debug geometry. Pieces use:

- layered silhouettes rather than single boxes;
- shared weathered stone, wet stone, timber, metal, moss, glow, and water materials;
- world-space color variation to reduce flat surfaces;
- continuous hidden collision beneath visual breakup where needed;
- architectural trim, masonry courses, braces, slats, hoops, moss, and localized lighting;
- consistent four-meter architecture dimensions.

The kit deliberately stops before imported production meshes, authored UV textures, decals, lightmaps, or final art direction.

## Ownership boundary

The reusable kit owns:

- repeated architecture and prop scenes;
- collision and pivots;
- material identity;
- catalog lookup and validation;
- a benchmark showcase for scale, camera, joins, and lighting.

Authored levels still own:

- floor plans and circulation;
- environmental history;
- landmark placement;
- sightlines and route readability;
- mood and final art direction;
- which modules are replaced by bespoke assets.

The existing `AuthoredEnvironmentBuilder` remains useful for blocking, invisible support collision, and one-off scaffolding. The modular kit should replace repeated runtime-built furniture and architecture as scenes mature.

## Canonical showcase

```text
scenes/levels/prototypes/prototype_modular_environment_showcase_v1.tscn
```

The **Weathered Cloister** is a coherent walkable set, not an asset grid. It demonstrates a continuous entrance, cloister walks, water channel, masonry walls, columns, timber frames, warm sconces, raised stairs, an operable iron gate, and a small prop gallery.

## Promotion rule

Add a new kit piece only when at least two authored spaces need the same structural or prop pattern. One-off landmarks remain inside their authored level until repetition proves a reusable scene is warranted.

## Next use

The next environment milestone should use this kit to remaster the Drowned Chapel nave and crypt entrance as the first production-representative benchmark room. That pass should replace repeated procedural architecture while preserving the quest, playability, and environment-composition contracts already proven there.
