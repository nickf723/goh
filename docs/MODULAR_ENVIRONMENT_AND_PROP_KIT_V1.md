# Modular Environment and Prop Kit v1

The modular environment kit is the first production-facing bridge between procedural prototype architecture and future imported art. It provides reusable Godot scenes with shared materials, matched collision, consistent scale, stable pivots, and dedicated benchmark spaces.

## Scope

The original **Weathered Cloister** family contains:

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

The **Weathered Village Outdoor** extension adds:

```text
weathered_village_road_4m
weathered_low_wall_4m
weathered_ruined_corner_4m
weathered_ruined_facade_6m
weathered_timber_fence_4m
weathered_rubble_cluster
weathered_olive_tree_cluster
```

Each asset is a reusable `.tscn` under `scenes/environment/modular/`. The catalog at `scripts/environment/modular_environment_catalog.gd` is the canonical lookup and validation owner.

## Visual target

This is still stylized low-poly prototype art, but it is no longer raw debug geometry. Pieces use:

- layered silhouettes rather than single boxes;
- shared weathered stone, wet stone, plaster, earth, timber, metal, moss, foliage, glow, and water materials;
- world-space color variation to reduce flat surfaces;
- continuous hidden collision beneath visual breakup where needed;
- architectural trim, masonry courses, braces, slats, hoops, roots, rubble, and localized lighting;
- consistent four-meter construction dimensions with a six-meter ruined façade.

The kit deliberately stops before imported production meshes, authored UV textures, decals, lightmaps, foliage LODs, or final art direction.

## Ownership boundary

The reusable kit owns:

- repeated architecture, terrain-edge vocabulary, vegetation clusters, and prop scenes;
- collision and pivots;
- material identity;
- catalog lookup and validation;
- benchmark sets for scale, camera, joins, lighting, outdoor density, and authored-scene integration.

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

## Interior story benchmark

```text
scenes/levels/prototypes/prototype_drowned_bell_v1.tscn
scripts/levels/drowned_bell_benchmark_remaster_pass.gd
docs/drowned_chapel_benchmark_remaster_v1_test.md
```

The **Drowned Chapel Benchmark** applies the kit to a complete persistent quest. Repeated visible architecture is modular, while the existing authored shell remains as continuous support collision. The memorial arcade, bell frame, rose window, pool shape, and quest machinery remain bespoke.

## Outdoor story benchmark

```text
scenes/levels/prototypes/prototype_ruined_village_approach_v1.tscn
scripts/levels/ruined_village_outdoor_remaster_pass.gd
data/set_layouts/ruined_village_outdoor_remaster_v1.json
docs/ruined_village_approach_v1_test.md
```

The **Ruined Village Outdoor Remaster** proves the same pipeline across a broad route with long sightlines, branching elemental crossings, open combat, terrain grades, ruined homes, vegetation, and a distant church landmark. Roads and ruined-building presentation reuse the original support terrain and foundations. Low walls and fences retain physical collision, while rubble and olive clusters remain nonblocking dressing.

The outdoor layout also carries protected routes, interaction zones, a combat clearing, and landmark zones through the shared readability auditor. This keeps the village broad and legible rather than turning the road into a decorated corridor.

## Promotion rule

Add a new kit piece only when at least two authored spaces need the same structural or prop pattern. One-off landmarks remain inside their authored level until repetition proves a reusable scene is warranted.

## Next use

The interior and outdoor benchmarks now cover the first reusable production loop. Perform a focused friction review before expanding the catalog again. Future authored content should reuse these pieces and add only patterns proven necessary by a real quest, town, dungeon, or Wilds landmark.
