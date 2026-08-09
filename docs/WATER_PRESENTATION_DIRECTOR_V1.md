# Water Presentation Director v1

## Goal

Water Presentation Director gives authored environment water a shared visual language without taking ownership of fluid physics, swimming, buoyancy, damage, or traversal.

```text
WaterPresentationProfile + authored water-role registration
                         ↓
              WaterPresentationDirector3D
                         ↓
     shared horizontal water shader / waterfall shader
```

The first benchmark is Green Grotto's existing localized water chain:

```text
upper stream -> waterfall -> lower basin
```

No water geometry is created or moved by this system.

## Shared shader strategy

Horizontal authored water reuses and extends:

```text
res://shaders/water_surface_v1.gdshader
```

This is the same shader used by `FluidForceVolume`. New fidelity parameters default to zero, so existing gameplay-fluid scenes preserve their v1 appearance until they explicitly opt in.

Green opts into:

- screen-space refraction;
- scene-depth-based shallow/deep tint;
- automatic shallow-edge foam;
- fresnel reflection tint;
- micro-wave normal breakup;
- world-space X/Z flow coordinates for irregular unwrapped meshes;
- deeper alpha/tint response in the basin.

Vertical falling water uses:

```text
res://shaders/waterfall_surface_v1.gdshader
```

The waterfall shader provides:

- downward animated streaks;
- cross-stream breakup;
- restrained sheet flutter;
- edge and terminal foam;
- screen-space refraction;
- fresnel tint;
- one shared material across all authored waterfall sheets.

## Why world-space flow exists

Green's V3 stream and basin are irregular `ArrayMesh` surfaces created with `SurfaceTool`. They intentionally do not require authored UV unwraps.

The evolved horizontal shader therefore exposes `world_space_flow`. Existing `FluidForceVolume` water leaves it at `0`, preserving UV-space behavior. Green sets it to `1`, so flow and micro-wave coordinates use world X/Z position and remain coherent across an irregular authored polygon.

## Green integration

Profile:

```text
data/water/green_grotto_water_presentation.tres
```

Integration layer:

```text
scripts/levels/prototype_green_grotto_water_pass.gd
```

Registered targets:

- `V3UpperStream` -> `stream`;
- `V3LowerBasin` -> `basin`;
- `V3WaterfallSheet00` through `03` -> `waterfall`.

Six meshes resolve to only three shared enhanced presentation materials.

## Ownership boundary

Water Presentation may:

- swap presentation materials;
- animate shader vertices/normals;
- sample screen color and opaque scene depth;
- tint by apparent water thickness;
- refract the opaque scene behind water;
- create visual foam from depth or shader coordinates;
- provide different presentation profiles for streams, basins, falls, oceans, ice melt, etc.

Water Presentation must not:

- create `FluidForceVolume` nodes;
- apply buoyancy or drag;
- decide whether Grace can swim;
- conduct electricity;
- apply elemental statuses;
- move water collision volumes;
- change quest/traversal state.

Gameplay-fluid systems remain authoritative for physical truth.

## A/B benchmark controls

Green Grotto now exposes:

```text
F2  Water Presentation ON/OFF
F3  Material Fidelity ON/OFF
F4  Surface Story ON/OFF
F5  Environmental Motion ON/OFF
F6  Camera Director ON/OFF
F7  Lighting quality tier
```

F2 restores the exact original material resource on every registered water mesh. Geometry is never rebuilt, so the comparison isolates water presentation alone.

## Best visual checks

1. **Upper stream:** look for directional motion, subtle refraction, shallow edge definition, and moving micro breakup.
2. **Waterfall:** look for a downward read instead of a translucent static ribbon, especially against high-contrast rock/background geometry.
3. **Lower basin:** look for darker apparent depth toward open water, stronger shallow-edge definition against banks, and a calmer slower surface than the stream.
4. Toggle F2 repeatedly from the same camera angle. The water should lose material depth and directional identity without moving or changing shape.

## Validation

```text
res://scenes/tests/water_presentation_director_smoke_test.tscn
```

The regression verifies:

- exactly one stream, one basin, and four waterfall surfaces;
- three shared enhanced materials for six meshes;
- world-space horizontal flow;
- depth/refraction/shoreline fidelity settings;
- shared waterfall material use;
- exact F2 material restoration without mesh replacement;
- coexistence with Material Fidelity, Surface Story, and Environmental Motion;
- backwards compatibility: a normal `FluidForceVolume` still leaves all new water-fidelity controls at their zero/default opt-in state.
