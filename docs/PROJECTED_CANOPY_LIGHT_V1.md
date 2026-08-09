# Projected Canopy Light v1

## Goal

Projected Canopy Light adds broad broken sunlight patterns to the Green Grotto without adding geometry or surface decals.

It is a secondary direct-light layer beneath the existing Lighting Director. The authored directional sun remains the scene's key light.

## Technique

The Director creates one `SpotLight3D` above the canopy break and assigns a runtime-generated grayscale projector texture.

The projector mask is generated from deterministic fractal noise plus an edge falloff. Bright regions represent canopy openings; dark regions suppress the secondary light.

The projector is intentionally low resolution (`96 × 96`). Its job is macro light breakup, not texture detail.

## Green placement

```text
position: (0, 18, 2)
rotation: (-90°, 0°, -6°)
range:    38m
angle:    38°
```

This covers the central canopy/causeway composition while remaining subordinate to the real sunset direction.

## F7 quality

### Performance

```text
visible = false
energy = 0
projector shadows = off
```

### Balanced

```text
energy = 0.42
volumetric energy = 0.22
projector shadows = on
```

### Cinematic

```text
energy = 0.68
volumetric energy = 0.38
projector shadows = on
```

A very slow rotation around the SpotLight's local forward axis shifts the projector pattern without changing its aim direction.

## GI rule

```text
light_indirect_energy = 0
```

The projected canopy light must never become a second source of bounced GI. SDFGI continues to receive the authored directional sun and other legitimate lighting sources.

## Ownership boundary

Projected Canopy Light may:

- create one direct SpotLight;
- assign a runtime projector texture;
- add low-energy patterned direct light;
- add restrained volumetric contribution;
- scale with F7 renderer quality.

It must not:

- replace the Lighting Director sun;
- alter environment exposure or fog settings;
- add indirect/GI energy;
- mutate geometry/materials;
- affect gameplay.

## Validation

```text
res://scenes/tests/projected_canopy_light_director_smoke_test.tscn
```

The regression verifies mask generation, authored placement, zero Performance cost, Balanced/Cinematic scaling, projector shadow support, zero indirect energy, and subordination to the main sun.
