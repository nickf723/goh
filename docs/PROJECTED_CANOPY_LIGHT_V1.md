# Projected Canopy Light v1

## Goal

Projected Canopy Light adds broad broken sunlight patterns to the Green Grotto without adding geometry or surface decals.

It is a secondary direct-light accent beneath the existing Lighting Director. The authored directional sun remains the scene's key light.

## Technique

The Director creates one `SpotLight3D` above the canopy break and assigns a runtime-generated grayscale projector texture.

The projector mask is generated from deterministic fractal noise plus an edge falloff. Bright regions represent canopy openings; dark regions suppress the secondary light.

After the Green visual-detox pass, the projector is intentionally tiny and cheap: a `64 × 64` mask, no indirect light, and no shadow map. The projector texture itself supplies the broken-canopy pattern. Paying for another shadow render of hundreds of procedural meshes was visually redundant and disproportionately expensive.

## Green placement

```text
position: (0, 18, 2)
rotation: (-90°, 0°, -6°)
range:    32m
angle:    34°
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
energy = 0.10
volumetric energy = 0.015
projector shadows = off
```

### Cinematic

```text
energy = 0.16
volumetric energy = 0.03
projector shadows = off
```

A very slow rotation around the SpotLight's local forward axis shifts the projector pattern without changing its aim direction.

## GI and shadow rule

```text
light_indirect_energy = 0
shadow_enabled = false
```

The projected canopy light must never become a second source of bounced GI or a second shadow authority. SDFGI and scene shadowing continue to come from the authored directional sun and legitimate local lights.

## Ownership boundary

Projected Canopy Light may:

- create one direct SpotLight;
- assign a runtime projector texture;
- add a very low-energy patterned direct accent;
- add a trace volumetric contribution;
- scale with F7 renderer quality.

It must not:

- replace the Lighting Director sun;
- allocate its own scene-wide shadow pass;
- alter environment exposure or fog settings;
- add indirect/GI energy;
- mutate geometry/materials;
- affect gameplay.

## Validation

```text
res://scenes/tests/projected_canopy_light_director_smoke_test.tscn
```

The regression verifies mask generation, authored placement, zero Performance cost, restrained Balanced/Cinematic scaling, a permanently shadow-free projector, zero indirect energy, and subordination to the main sun.
