# Render Image Quality Director v1

## Goal

Render Image Quality Director makes the existing F7 renderer-quality ladder control final image reconstruction as well as scene lighting/shadows/reflections.

It modifies only the active Viewport at runtime. It does not rewrite project settings.

## Green Grotto quality ladder

### Performance

```text
TAA          OFF
Screen AA    FXAA
MSAA 3D      OFF
Debanding    OFF
```

This is the low-cost benchmark state.

### Balanced

```text
TAA          ON
Screen AA    OFF
MSAA 3D      OFF
Debanding    ON
```

Balanced uses temporal antialiasing to reduce shader/specular/transparency shimmer without stacking an additional screen-space post-process AA pass.

### Cinematic

```text
TAA          ON
Screen AA    OFF
MSAA 3D      OFF
Debanding    ON
```

The original Cinematic experiment stacked 2x MSAA on top of TAA. The Green visual-detox pass removed that stack after the benchmark became GPU-heavy. Cinematic now means the highest useful authored presentation, not every available antialiasing switch enabled simultaneously.

If a future asset set exposes geometry-edge aliasing that TAA cannot handle, F11 measurements can justify reintroducing MSAA for that target specifically.

## Why these techniques

The Green benchmark contains several aliasing stressors:

- thin railings and architectural ribs;
- moving foliage;
- strong water/specular highlights;
- small decals and surface detail;
- high-contrast diagonal ruin silhouettes.

Performance uses FXAA because it is the cheapest broad edge treatment in the Forward+ target. Balanced and Cinematic use TAA because temporal accumulation is better suited to moving/specular shader aliasing. Debanding remains useful for the grotto's fog and sunset gradients.

## Runtime ownership

`RenderImageQualityDirector` captures the Viewport's original:

```text
use_taa
screen_space_aa
msaa_3d
use_debanding
```

Disabling the Director restores those exact values.

It follows `LightingDirector3D.quality`, so it automatically participates in:

```text
F7 Performance → Balanced → Cinematic
F9 BASELINE → BALANCED → HERO
```

## Ownership boundary

Render Image Quality may:

- configure root Viewport 3D antialiasing;
- configure Viewport debanding;
- change those settings when F7 quality changes;
- restore the exact previous Viewport state when disabled.

Render Image Quality must not:

- change scene geometry;
- alter materials;
- change lighting/exposure/fog;
- change shadow or reflection quality directly;
- change project settings;
- change gameplay state.

## Validation

```text
res://scenes/tests/render_image_quality_director_smoke_test.tscn
```

The regression verifies the real Viewport values for all three F7 tiers and exact restoration of the pre-Director state.
