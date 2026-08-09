# Lighting Director v1

## Goal

Lighting Director is the shared cinematic-lighting authority for authored 3D spaces.
It separates **visual state** from level gameplay and replaces one-off per-level lighting tweaks with reusable data profiles and spatial blends.

```text
LightingProfile + Grace position + LightingZone3D
                    ↓
              LightingDirector3D
                    ↓
WorldEnvironment / sun / fill / camera exposure / GI / fog
```

## Core files

```text
scripts/lighting/lighting_profile.gd
scripts/lighting/lighting_zone_3d.gd
scripts/lighting/lighting_director_3d.gd
```

`LightingProfile` stores the authored look. `LightingZone3D` describes where another look becomes dominant. `LightingDirector3D` resolves the active profiles, blends them smoothly, and applies the result to the existing Godot rendering stack.

## Profile vocabulary

Profiles currently own:

- procedural-sky colors and energy;
- key sun direction, color, intensity and shadow range;
- cool/warm fill direction and intensity;
- ambient color and energy;
- filmic tonemap exposure and white point;
- `CameraAttributesPractical` exposure and auto-exposure behavior;
- traditional fog;
- volumetric fog color, density, anisotropy, range and GI/ambient contribution;
- restrained glow;
- SSAO;
- SSIL;
- SSR;
- SDFGI energy and quality configuration.

## Quality tiers

### Performance

- traditional fog remains available;
- volumetric fog is disabled;
- SDFGI, SSIL and SSR are disabled;
- basic sun/fill/ambient/exposure/SSAO/profile blending remains intact.

### Balanced

- volumetric fog is enabled when requested by the profile;
- SDFGI and SSIL are enabled when requested;
- SDFGI cascade/detail cost is reduced;
- SSR remains disabled.

### Cinematic

- full authored profile;
- volumetric fog;
- SDFGI;
- SSIL;
- SSR;
- profile-defined GI detail and reflection budget.

Green Grotto currently uses Cinematic as its art-target tier.

## Spatial zones

A `LightingZone3D` is an oriented box with a soft blend boundary. The Director samples Grace's world position each frame. Zones are processed by priority, allowing a specific shrine or waterfall profile to refine a broader grotto/canopy profile.

Zones may also own **spatial** presentation that should physically exist only there:

- local `FogVolume`;
- local OmniLight accent/bounce.

This is different from changing the global profile. A waterfall mist volume exists in world space; its cooler global exposure/fill treatment is a profile blend.

## Green Grotto reference integration

Profiles:

```text
data/lighting/green_grotto_base.tres
data/lighting/green_grotto_entrance.tres
data/lighting/green_grotto_canopy_break.tres
data/lighting/green_grotto_waterfall.tres
data/lighting/green_grotto_shrine.tres
```

Zones:

```text
EntranceShadowZone
CanopyBreakZone
WaterfallZone
ShrineZone
```

The integration layer at:

```text
scripts/levels/prototype_green_grotto_lighting_pass.gd
```

retires the two old hand-authored local bounce lights. The existing `GreenGrottoEnvironment`, `CanopySunset`, and `GrottoGreenFill` remain stable hierarchy seams, but their values are now driven by `LightingDirector3D`.

## Ownership rules

Lighting code may report and modify visual state only. It must not decide:

- combat outcomes;
- encounter activation;
- traversal rules;
- spell behavior;
- weather gameplay consequences;
- music logic;
- quest state.

Other systems may request/swap a profile later, but Lighting Director remains a presentation authority rather than a gameplay authority.

## Future extensions

Good next additions after Green tuning:

1. profile libraries for each dungeon/biome;
2. explicit weather/time-of-day profile overlays;
3. camera-specific cinematic overrides for dialogue and cutscenes;
4. reflection-probe orchestration for interiors;
5. optional LightmapGI profiles for fixed-lighting production spaces;
6. developer overlay showing active zones and blended exposure/fog/GI values.

## Validation

```text
res://scenes/tests/lighting_director_smoke_test.tscn
```

The regression verifies Director initialization, Green render-target ownership, Cinematic quality features, zone blend behavior, local fog/accent installation, and retirement of legacy manual bounce lights.
