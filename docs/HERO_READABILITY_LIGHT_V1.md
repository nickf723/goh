# Hero Readability Light v1

## Goal

Hero Readability Light gives Grace a restrained camera-relative rim/fill that preserves her silhouette in deep environmental shadow without brightening the world around her.

The first integration is the Green Grotto benchmark.

## Render-layer isolation

Grace remains on her ordinary render layer and receives one additional private layer:

```text
world / Grace normal rendering: layer 1
Grace readability lighting:     layer 2
```

The readability `DirectionalLight3D` uses a cull mask containing only layer 2. World geometry remains outside layer 2, so the extra light cannot illuminate rocks, ruins, foliage, water, or atmospheric detail.

The Director records each Grace `VisualInstance3D` layer mask before adding the private bit. Disabling the Director restores the exact previous masks.

## Light behavior

The light is camera-relative rather than world-authored. Its source direction is derived from a smoothed position behind and slightly to one side of the camera-facing relationship to Grace.

The intent is edge separation, not an obvious spotlight.

```text
color: cool blue-white
shadows: off
indirect GI energy: 0
volumetric fog energy: 0
sky contribution: light-only
```

The zero indirect and volumetric values are important because those rendering paths do not provide the same per-object cull isolation as ordinary direct lighting.

## F7 quality

### Performance

```text
energy = 0
visible = false
```

### Balanced

```text
energy = 0.18
```

### Cinematic

```text
energy = 0.30
```

The light follows the same F7 quality value used by the rest of the benchmark and therefore follows F9 BASELINE/BALANCED/HERO presets.

## Ownership boundary

Hero Readability Light may:

- add a private render-layer bit to Grace presentation meshes;
- create one shadow-free directional presentation light;
- orient that light relative to the active camera;
- scale energy with renderer quality;
- restore exact original layer masks when disabled.

It must not:

- change Grace geometry or animation;
- alter world lighting;
- contribute GI or volumetric fog;
- cast shadows;
- change gameplay visibility, stealth, targeting, or perception.

## Validation

```text
res://scenes/tests/hero_readability_light_director_smoke_test.tscn
```

The regression verifies private-layer isolation, world exclusion, Performance/Balanced/Cinematic energy, zero GI/fog/shadow contribution, and exact layer restoration.
