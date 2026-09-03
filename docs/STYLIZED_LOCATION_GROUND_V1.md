# Stylized Location Ground V1

`stylized_location_ground_v1.gdshader` is the reusable organic surface layer for authored outdoor locations. It extends the existing authored-environment composition capability; it does not replace terrain geometry, collision, navigation, or scene ownership.

## First preset

Golden Meadow owns the first material preset at `art/materials/environment/natural/stylized_pbr_meadow_ground_v1.tres`. The preset favors short green turf broken by broad earth patches, dry growth, small stone flecks, and shallow procedural relief. Its surface script also demonstrates deterministic geometry-backed earth patches and pebble scatter, ensuring the authored breakup remains legible when dense vegetation or strong lighting obscures shader-only variation. The optional path mask is disabled so the benchmark remains an empty field.

## Location controls

Duplicate the material preset for a new location and tune:

- turf, dry-grass, soil, stone, and rim palettes;
- `location_offset` to prevent repeated world patterns between authored sets;
- domain warp, turf scale, soil scale, threshold, softness, amount, and slope bias;
- pebble scale and amount;
- micro color and normal relief;
- optional path direction, origin, width, edge softness, wobble, and soil coverage.

The shader uses world-space XZ coordinates. Adjacent meshes that share a preset line up without UV authoring, while different presets can use distinct offsets.

## Versioned seeded recipes

`OrganicSurfaceRecipe` wraps a material preset with a generator version, seed,
and bounded variation ranges. It derives location offset, patch scale, dryness,
soil coverage, pebble coverage, and relief deterministically, then records the
recipe ID, generator version, seed, and signature on the generated material.

The build method compensates for a mesh's world anchor. Two separate models
using the same recipe and seed therefore receive the same pattern in local
coordinates instead of sampling unrelated parts of the world-space texture.
Changing generator math requires a new `generator_version`; a seed by itself is
not a complete reproducibility contract.

The canonical comparison scene is:

```text
res://scenes/levels/prototypes/prototype_organic_surface_lab_v1.tscn
```

Its identical-seed twins, deterministic seed banks, exact rebuild action, and
copyable signatures isolate recipe repeatability from the finished Golden
Meadow composition.

## Geometry contract

Procedural relief uses tangent-space normal mapping. Generated terrain meshes must provide a complete tangent array in addition to vertices, normals, UVs, and indices. Terrain collision should use a terrain-specialized heightmap whenever the surface has no overhangs; Golden Meadow samples the same height function for rendering, collision, spawn placement, patch overlays, and pebble placement. The smoke test rejects incomplete tangents, mismatched collision ownership, hidden dirt coverage, or missing detail geometry.

## Scope

This is a scalable authored-location base, not a final library of biome textures. Keep each material preset location-specific, validate it in its intended lighting, and only migrate a preset into broader world content after its readability and performance are approved.
