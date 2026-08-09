# Reflection Fidelity Director v1

## Goal

Reflection Fidelity adds local image-based reflections to authored spaces without replacing the existing Lighting Director, SDFGI, SSR, materials, or gameplay systems.

```text
ReflectionRegion3D authoring volumes
             ↓
ReflectionFidelityDirector3D ← LightingDirector F7 quality
             ↓
      native ReflectionProbe nodes
```

## Core files

```text
scripts/reflections/reflection_fidelity_profile.gd
scripts/reflections/reflection_region_3d.gd
scripts/reflections/reflection_fidelity_director_3d.gd
```

## Ownership boundary

Reflection Fidelity may:

- create native ReflectionProbe captures for authored regions;
- control probe intensity, visibility, LOD threshold, capture distance, and capture shadows;
- use box projection where the authored space benefits from parallax correction;
- follow Lighting Director quality tiers;
- blend with the renderer's existing environment/SDFGI/SSR reflection stack.

Reflection Fidelity must not:

- change light color or energy;
- change geometry, materials, collision, water physics, or traversal;
- create gameplay light sources;
- decide whether a surface is wet, metallic, or reflective;
- use UPDATE_ALWAYS for ordinary static environment captures.

## Green Grotto reference integration

Green authors four regions:

```text
Entrance Hollow
Canopy Vista
Waterfall Bowl
Shrine Court
```

The entrance and shrine use box projection because their architecture is comparatively room-like. The irregular waterfall ravine and open canopy use ordinary probe projection.

Quality behavior follows F7:

```text
Performance  0 probes
Balanced     Entrance + Waterfall + Shrine, UPDATE_ONCE, no probe shadows
Cinematic    all 4 probes, UPDATE_ONCE, capture shadows enabled
```

The Canopy Vista is Cinematic-only because it is the broadest capture and adds the least value at lower tiers.

## Why UPDATE_ONCE

The grotto is predominantly static. Local reflection captures should therefore be rendered when the probe becomes active rather than continuously re-rendered every frame. Dynamic near-screen reflection remains the responsibility of SSR and the rest of the renderer stack.

## Validation

```text
res://scenes/tests/reflection_fidelity_director_smoke_test.tscn
```

The regression verifies:

- exactly four authored Green regions;
- native ReflectionProbe installation;
- box-projection policy;
- UPDATE_ONCE capture policy;
- Performance/Balanced/Cinematic probe budgets;
- reflection capture shadow policy;
- F7 synchronization;
- coexistence with SSR, Shadow Fidelity, Material Fidelity, and Water Presentation.
