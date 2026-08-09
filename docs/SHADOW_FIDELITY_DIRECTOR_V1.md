# Shadow Fidelity Director v1

## Goal

Shadow Fidelity makes authored lighting feel grounded without changing level geometry or creating fake contact decals.

It follows the existing `LightingDirector3D` quality tier instead of introducing another user-facing quality switch.

```text
Lighting Director F7 quality
          ↓
ShadowFidelityProfile
          ↓
ShadowFidelityDirector3D
          ↓
directional atlas / PSSM / bias / softness / local shadows / foliage shadow policy
```

## Core files

```text
scripts/shadows/shadow_fidelity_profile.gd
scripts/shadows/shadow_fidelity_director_3d.gd
```

Green reference profile:

```text
data/shadows/green_grotto_shadow_fidelity.tres
```

Green integration:

```text
scripts/levels/prototype_green_grotto_shadow_pass.gd
```

## Ownership boundary

Shadow Fidelity may:

- choose the directional shadow atlas budget;
- choose positional shadow atlas size for local lights;
- choose directional soft-shadow filter quality;
- select 2-split or 4-split directional PSSM;
- tune directional split locations and fade start;
- tune bias, normal bias, blur, opacity, angular distance, and pancake size;
- enable local accent-light shadows when a quality tier can afford them;
- change `GeometryInstance3D.cast_shadow` for enrolled thin vegetation.

Shadow Fidelity must not:

- create or move lights;
- change light color or energy;
- change environment exposure, GI, fog, or post processing;
- change materials;
- change geometry or collision;
- decide gameplay visibility or stealth;
- fake contact shadows with decals.

Lighting Director remains the lighting-state authority. Shadow Fidelity only describes the rendering quality of those authored lights.

## Quality tiers

### Performance

- 2048 directional atlas;
- 1024 positional atlas;
- 2 directional PSSM splits;
- short shadow range;
- cheap shadow filtering;
- no contact-hardening angular sun size;
- no local accent shadows;
- foliage restores its authored single-sided shadow policy.

### Balanced

- 4096 directional atlas;
- 2048 positional atlas;
- 4 directional PSSM splits;
- medium soft-shadow filtering;
- restrained sun angular distance;
- tighter bias and normal bias;
- close ground/sunlit foliage receives double-sided shadow casting;
- canopy remains on the cheaper policy;
- local accent shadows remain disabled.

### Cinematic

- 8192 directional atlas;
- 4096 positional atlas;
- 4 directional PSSM splits;
- high soft-shadow filtering;
- longest useful shadow range;
- sun angular distance approximates a broad natural light source for contact-hardening softness;
- tight bias/normal-bias values improve contact grounding;
- all enrolled vegetation can cast double-sided shadows;
- Green's two small zone accent lights may cast local shadows.

The large Cinematic atlas is an art-target benchmark setting, not a commitment that every shipping platform must use the same budget.

## Green Grotto

The benchmark resolves the existing authored sun:

```text
GreenGrottoArt/Lighting/CanopySunset
```

It also discovers the two local lights created by the Lighting Zones:

```text
WaterfallZone/ZoneAccent
ShrineZone/ZoneAccent
```

No new Green lights are created by Shadow Fidelity.

Thin vegetation is discovered through the existing `vegetation_presentation_target` group. Shadow Fidelity stores each mesh's authored `cast_shadow` value so cheaper tiers can restore the exact original setting.

## Benchmark control

Shadow Fidelity deliberately has no dedicated hotkey.

```text
F1  Vegetation Presentation
F2  Water Presentation
F3  Material Fidelity
F4  Surface Story
F5  Environmental Motion
F6  Camera Director
F7  Lighting + Shadow quality tier
```

F7 now changes both the lighting feature budget and the shadow-map budget as one coherent renderer-quality control.

## Validation

```text
res://scenes/tests/shadow_fidelity_director_smoke_test.tscn
```

The regression verifies:

- Green installs the shared Shadow Fidelity system;
- the authored sunset sun is reused rather than replaced;
- Performance uses a smaller atlas, two splits, short range, no local accent shadows, and no double-sided foliage shadows;
- Balanced restores four splits and close-foliage double-sided shadows while keeping canopy/local lights cheaper;
- Cinematic restores the full atlas/filter/range budget, contact-hardening sun softness, all foliage shadow policy, and both Green local accent shadows;
- cycling F7 restores each tier deterministically;
- vegetation mesh geometry and material ownership remain unchanged.
