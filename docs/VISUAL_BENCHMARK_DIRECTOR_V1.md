# Visual Benchmark Director v1

## Goal

The Green Grotto contains multiple independent presentation systems. Visual Benchmark Director provides stable whole-stack comparison presets without replacing their individual debug controls.

The benchmark covers both the explicit F1-F6 switches and the systems that automatically follow the F7 renderer-quality tier.

## Presets and controls

```text
F9   BASELINE → BALANCED → HERO
F10  Benchmark status HUD ON/OFF
F11  Capture current state for 5 seconds
```

### BASELINE

```text
F1 Vegetation Presentation OFF
F2 Water Presentation OFF
F3 Material Fidelity OFF
F4 Surface Story OFF
F5 Environmental Motion OFF
F6 Camera Director OFF
F7 Lighting Performance
```

F7-linked systems also collapse to their Performance behavior:

- Shadow Fidelity = Performance;
- Reflection Fidelity = zero local probes;
- Atmospheric Detail = zero visible motes;
- Grace Character Material Presentation = exact original materials;
- Visual LOD = Performance detail ranges;
- Surface Contact Presentation = zero extra pieces;
- Image Fidelity = raw viewport: no TAA, 3D MSAA, screen-space AA, or debanding.

Ambient Green fauna acting is also disabled. Each creature hands presentation authority back to the original simple `GreenGrottoFaunaVisual` patrol animator so the baseline remains comparable to the earlier benchmark.

### BALANCED

All F1-F6 presentation systems and ambient fauna acting are enabled. Lighting Director uses the Balanced tier.

F7-linked systems follow Balanced automatically:

- Balanced shadows;
- three local reflection regions;
- reduced-density entrance/canopy/waterfall atmosphere;
- Balanced Grace material variants;
- Balanced Visual LOD distances;
- three contact pieces per footstep and seven per landing;
- TAA + debanding + screen-space roughness limiting, with 3D MSAA disabled.

### HERO

All F1-F6 presentation systems and ambient fauna acting are enabled. Lighting Director uses Cinematic.

F7-linked systems follow Cinematic automatically:

- full Shadow Fidelity budget;
- all four local reflection regions;
- all 460 authored atmosphere instances;
- Cinematic Grace material variants including restrained skin SSS/transmittance;
- longest Green Visual LOD ranges;
- five contact pieces per footstep and eleven per landing;
- TAA + 2x 3D MSAA + debanding + stronger screen-space roughness limiting.

This is the benchmark's maximum-quality authored presentation state.

## Custom state

Individual F1-F7 controls remain authoritative. If a user changes any of them after applying a preset, the benchmark readout reports `CUSTOM` instead of pretending the current stack still matches a named preset.

Ambient fauna state is also part of preset detection.

## Overlay

The benchmark creates a development-only `CanvasLayer` status panel. It reports:

- current matched preset;
- rolling FPS and frame time;
- current draw calls and rendered primitives;
- F1-F6 ON/OFF state;
- current F7 lighting tier;
- active ReflectionProbe count;
- visible atmospheric-detail instance count;
- Visual LOD managed-target count;
- final image mode (`RAW`, `TAA`, `TAA+2x`);
- Grace material quality tier;
- current footstep surface-contact piece budget;
- ambient fauna acting ON/OFF;
- F9/F10/F11 controls;
- the last completed timed benchmark result.

The overlay exists only because the Green art target explicitly installs Visual Benchmark Director. It is not part of the production HUD.

## Timed capture

F11 records the current visual state over a short window instead of trusting one frame. The result records:

```text
preset/state label
sample count
average FPS
average frame time in milliseconds
1% low FPS estimate
average draw calls
average rendered primitives
```

Recommended comparison:

```text
fixed camera position
→ F9 BASELINE → wait briefly → F11
→ F9 BALANCED → wait briefly → F11
→ F9 HERO → wait briefly → F11
```

Keep Grace and the camera still during each capture when the goal is renderer comparison. Movement/combat benchmarks can be run separately later.

The short wait after changing presets gives shadow/reflection/environment/image state and engine performance monitors time to settle before measurement.

## Validation

```text
res://scenes/tests/visual_benchmark_director_smoke_test.tscn
```

The regression verifies:

- exact BASELINE, BALANCED, and HERO F1-F7 states;
- legacy-vs-ambient fauna authority handoff;
- reflection/shadow synchronization;
- atmosphere density per tier;
- Grace material quality per tier;
- surface-contact density per tier;
- Visual LOD Cinematic synchronization;
- CUSTOM detection;
- the benchmark-only overlay;
- a deterministic short telemetry capture.

Image Fidelity has an additional direct viewport regression at:

```text
res://scenes/tests/image_fidelity_director_smoke_test.tscn
```

For the broader scene-level testing contract, see:

```text
res://docs/GREEN_GROTTO_VISUAL_LAB_V1.md
```
