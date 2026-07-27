# Modular Environment and Prop Kit v1

The modular environment kit is the first production-facing bridge between procedural prototype architecture and future imported art. It provides reusable Godot scenes with shared materials, matched collision, consistent scale, stable pivots, and dedicated benchmark spaces.

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
- benchmark sets for scale, camera, joins, lighting, and authored-scene integration.

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

## Story-integrated benchmark

```text
scenes/levels/prototypes/prototype_drowned_bell_v1.tscn
scripts/levels/drowned_bell_benchmark_remaster_pass.gd
docs/drowned_chapel_benchmark_remaster_v1_test.md
```

The **Drowned Chapel Benchmark** applies the same kit to a complete persistent quest. Repeated visible architecture is modular, while the existing authored shell remains as continuous support collision. This preserves the finished quest and Global Playability guarantees while testing modular floors, walls, arches, pillars, timber frames, sconces, water transitions, presentation pedestals, and physical props under real exploration pressure.

The memorial arcade, bell frame, rose window, pool shape, and quest machinery remain bespoke. This is the intended boundary: common construction repeats, landmarks remember where they are.

## Promotion rule

Add a new kit piece only when at least two authored spaces need the same structural or prop pattern. One-off landmarks remain inside their authored level until repetition proves a reusable scene is warranted.

## Next use

The next environment milestone should apply the proven kit to a larger existing route, preferably the Church Trial or Ruined Village Approach. That second story-integrated application should reveal which additions are genuinely reusable, such as corners, ruined wall variants, ceiling or vault pieces, railings, doors, and terrain-to-architecture transitions.
