# Atmospheric Detail Director v1

## Goal

Atmospheric Detail adds restrained micro-scale depth cues to authored environments without introducing an external particle-art dependency or gameplay weather authority.

The first Green Grotto integration uses four batched fields:

```text
EntranceDustField
CanopyPollenField
WaterfallMistField
ShrineMoteField
```

## Architecture

```text
Lighting Director quality (F7)
          +
Environmental Motion visual wind (F5, when enabled)
          ↓
AtmosphericDetailDirector3D
          ↓
4 MultiMesh billboard fields
```

The Director owns presentation instances only.

## Batching

Atmospheric fields use `MultiMeshInstance3D` rather than one node per mote. Green authors 460 maximum instances across four fields while retaining four batched field nodes.

A small soft alpha texture is generated at runtime in Godot and shared as the shape source for each field's billboard material. No external texture asset is required for v1.

## Green Grotto fields

### Entrance dust

- 70 maximum instances;
- sheltered warm dust;
- low wind response;
- available from Balanced upward.

### Canopy pollen

- 170 maximum instances;
- warm gold-green motes designed to reveal sunset shafts;
- stronger response to Environmental Motion wind;
- available from Balanced upward.

### Waterfall mist

- 150 maximum instances;
- larger, lower-alpha cool billboards;
- upward drift plus restrained lateral wind;
- available from Balanced upward.

### Shrine motes

- 70 maximum instances;
- sparse warm court dust;
- Cinematic only so the focal architecture remains clean at lower tiers.

## F7 quality contract

Atmospheric Detail has no independent benchmark key.

```text
Performance  0% density
Balanced     48% density on Balanced-eligible fields
Cinematic    100% authored density
```

This means the existing F9 benchmark presets automatically include the correct atmosphere cost through their F7 tier:

```text
BASELINE → no atmosphere
BALANCED → reduced entrance/canopy/waterfall atmosphere
HERO → all four fields at full density
```

## Motion relationship

When Environmental Motion is enabled, each atmosphere field samples the same visual wind used by foliage and Grace accessory motion. Atmospheric drift does not create or modify that wind.

When F5 is disabled, the fields retain only their small intrinsic vertical/oscillatory drift. They do not fabricate a replacement wind system.

## Ownership boundary

Atmospheric Detail may:

- render batched dust, pollen, or mist-like presentation billboards;
- scale visible density with Lighting Director quality;
- sample Environmental Motion visual wind;
- use deterministic procedural placement and drift;
- generate its own tiny presentation texture at runtime.

Atmospheric Detail must not:

- apply force to gameplay actors or projectiles;
- define AirflowManager fields;
- decide weather gameplay;
- alter fog collision or visibility mechanics;
- alter stealth/detection;
- own final production particle art.

The v1 fields are deliberately replaceable presentation infrastructure. Final art can swap meshes/textures/shaders while preserving the density, quality, and wind contracts.

## Validation

```text
res://scenes/tests/atmospheric_detail_smoke_test.tscn
```

The regression verifies:

- exactly four Green fields and 460 authored instances;
- MultiMesh batching;
- runtime-generated soft texture;
- Performance = 0 visible instances;
- Balanced = reduced density and no shrine field;
- Cinematic = all 460 instances;
- atmospheric transforms drift over time;
- Environmental Motion is available as the wind source;
- no gameplay authority is introduced.
