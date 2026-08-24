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

The approved hero-pedestal rock remains the shape reference. In v1.2, the left cloister wing stays on `modular_surface.gdshader` while matching forms on the right wing receive the stylized-PBR material family. Production routes remain unchanged.

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

The approved stone preset uses broad teal-gray variation, high roughness, zero metallic response, a cool blue rim, and a restrained saturation lift.

The v1.2 showcase family adds:

| Family | Resource | Physical read |
| --- | --- | --- |
| Stone | `stylized_pbr_stone_study.tres` | Rough teal-gray masonry and rock |
| Wet stone | `stylized_pbr_wet_stone_v1.tres` | Sharper, darker moisture response |
| Dry earth | `stylized_pbr_dry_earth_v1.tres` | Very rough warm terrain mass |
| Aged wood | `stylized_pbr_aged_wood_v1.tres` | Broad warm grain-like breakup without fine noise |
| Aged metal | `stylized_pbr_aged_metal_v1.tres` | Metallic GGX response with restrained color and rim |

`scripts/environment/stylized_pbr_material_library.gd` owns preset lookup, validation, and bounded legacy-material remapping.

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

These are calibration values, not a final global environment resource. The in-world console beside the gate switches to `violet_twilight_v1`, replacing the warm key with cool violet light while retaining warm sconces as local focal contrast. Local art dialects still own their palette and dominant lighting idea.

## Review order

1. Read the rock silhouette from the entrance and at pedestal distance.
2. Compare its value grouping against the surrounding legacy stone.
3. Rotate the camera and verify that the cool rim separates edges without becoming an outline.
4. Confirm the direct highlight moves continuously and remains physically sharp.
5. Check that the shadow band is painterly rather than a hard cel boundary.
6. Check that broad variation supports the form instead of creating procedural speckle.
7. Judge Grace against both the warm key and cool sky.

## Rollout gate

The first stone preset is manually approved. V1.2 now proves the broad material family in one A/B showcase and exposes a second strongly different lighting dialect.

Before production migration:

1. approve the left/right family comparison in both daylight and violet twilight;
2. verify Grace readability without applying the material to Grace;
3. choose one authored route for a bounded, reversible material pass;
4. keep foliage, creatures, VFX, and Grace outside that route pass;
5. retain per-material control over ramp, roughness, metallic response, and rim strength.

## Validation

```text
res://scenes/tests/modular_environment_showcase_smoke_test.tscn
```

The regression verifies shader resource loading, required uniforms, five material presets, independent diffuse and specular paths, the left/right rollout boundary, legacy preservation, daylight/twilight switching, procedural sky, ACES grading, and SSAO.


## Approval history

- v1.1 stone calibration: approved by Nick on 2026-08-23.
- v1.2 material-family and second-lighting-dialect comparison: awaiting manual review.
