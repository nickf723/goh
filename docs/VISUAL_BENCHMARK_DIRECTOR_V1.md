# Visual Benchmark Director v1

## Goal

The Green Grotto now contains multiple independent presentation systems. Visual Benchmark Director provides stable whole-stack comparison presets without replacing their individual debug controls.

## Presets

```text
F9  BASELINE → BALANCED → HERO
F10 Benchmark status HUD ON/OFF
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

Shadow Fidelity and Reflection Fidelity follow the Performance lighting tier automatically.

### BALANCED

All F1-F6 presentation systems are enabled and Lighting Director uses the Balanced tier. Shadow and reflection systems follow Balanced automatically.

### HERO

All F1-F6 presentation systems are enabled and Lighting Director uses Cinematic. This is the benchmark's maximum-quality authored presentation state.

## Custom state

Individual F1-F7 controls remain authoritative. If a user changes any of them after applying a preset, the benchmark readout reports `CUSTOM` instead of pretending the current stack still matches a named preset.

## Overlay

The benchmark creates a development-only CanvasLayer status panel. It reports:

- current matched preset;
- F1-F6 ON/OFF state;
- current F7 lighting tier;
- F9/F10 controls.

The overlay exists only because the Green art target explicitly installs Visual Benchmark Director. It is not part of the production HUD.

## Validation

```text
res://scenes/tests/visual_benchmark_director_smoke_test.tscn
```

The regression verifies exact BASELINE, BALANCED, and HERO state changes, reflection/shadow synchronization, CUSTOM detection, and the benchmark-only overlay contract.
