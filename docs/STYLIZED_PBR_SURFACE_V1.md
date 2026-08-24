# Stylized PBR Surface v1

## Goal

Establish a provisional global surface treatment that preserves grounded material response while replacing fully smooth diffuse shading with a softer painterly value structure.

This pass follows the Global Art Bible:

- stylized forms with grounded rendering;
- material response before texture noise;
- saturated but controlled color;
- warm/cool lighting separation;
- no repo-wide visual rollout before a contained comparison succeeds.

## Canonical calibration location

```text
res://scenes/levels/prototypes/prototype_modular_environment_showcase_v1.tscn
```

The hero pedestal contains one three-lobe low-poly rock named `StylizedSurfaceStudy`. The surrounding Weathered Cloister continues using `modular_surface.gdshader`, producing a direct in-scene comparison rather than silently changing every environment material.

## Shader

```text
res://shaders/environment/stylized_pbr_surface_v1.gdshader
```

The shader provides:

- albedo, normal, roughness, and metallic texture seams;
- broad world-space color variation without high-frequency noise;
- adjustable material saturation;
- a three-value diffuse ramp with soft transitions;
- Fresnel-based colored rim emission;
- an unquantized Cook-Torrance GGX direct specular lobe;
- ordinary shadow attenuation and sky/environment contribution.

The diffuse and specular paths remain separate. Tuning the painterly ramp must not posterize highlights.

## First material

```text
res://art/materials/environment/modular/stylized_pbr_stone_study.tres
```

The first preset is intentionally a stone study, not a claimed universal material. It uses broad teal-gray variation, high roughness, zero metallic response, a cool blue rim, and a restrained saturation lift.

## Primary tuning controls

| Control | Purpose |
| --- | --- |
| `band_midpoint` | Position of the shadow-to-middle transition |
| `band_highlight` | Position of the middle-to-light transition |
| `band_softness` | Width of both painterly transitions |
| `shadow_band_level` | Direct-light value on shallow-facing surfaces |
| `middle_band_level` | Direct-light value before the highlight band |
| `rim_color` | Local silhouette-separation hue |
| `rim_intensity` | Strength of the Fresnel rim |
| `rim_power` | Width and falloff of the rim |
| `saturation` | Per-material color lift |
| `roughness_value` | GGX highlight spread |
| `metallic_value` | Metallic response |
| `broad_variation_strength` | Large-scale painted color breakup |

## Calibration lighting

The showcase uses:

- a warm orange-gold DirectionalLight3D key;
- a cool three-tone ProceduralSkyMaterial;
- sky-sourced ambient light;
- ACES tonemapping;
- 116 percent saturation and light contrast/brightness adjustments;
- moderate SSAO for contact and form grounding.

These are calibration values, not a final global environment resource. Local art dialects will still own their palette and dominant lighting idea.

## Review order

1. Read the rock silhouette from the entrance and at pedestal distance.
2. Compare its value grouping against the surrounding legacy stone.
3. Rotate the camera and verify that the cool rim separates edges without becoming an outline.
4. Confirm the direct highlight moves continuously and remains physically sharp.
5. Check that the shadow band is painterly rather than a hard cel boundary.
6. Check that broad variation supports the form instead of creating procedural speckle.
7. Judge Grace against both the warm key and cool sky.

## Rollout gate

Do not migrate terrain, architecture, props, foliage, creatures, or Grace until the first stone preset is manually approved.

After approval:

1. tune stone under at least two strongly different lighting dialects;
2. author separate presets for terrain, dry wood, wet stone, and aged metal;
3. test Grace readability without applying the material to Grace;
4. migrate one authored route in bounded batches;
5. retain easy per-material control over ramp and rim strength.

## Validation

```text
res://scenes/tests/modular_environment_showcase_smoke_test.tscn
```

The regression verifies shader resource loading, required uniforms, independent diffuse and specular paths, the single-prop rollout boundary, the study material, procedural sky, warm key, ACES grading, and SSAO.
