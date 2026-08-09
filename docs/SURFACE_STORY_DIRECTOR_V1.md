# Surface Story Director v1

## Goal

Surface Story Director adds believable history and material variation to existing geometry without requiring mesh remodeling or external texture authoring.

```text
SurfaceStoryProfile + authored world-space stamps
                         ↓
                SurfaceStoryDirector3D
                         ↓
           native Godot Decal projection layer
```

The system is intended to answer **why a surface looks different here** rather than scatter generic noise everywhere.

## Core files

```text
scripts/surface_story/surface_story_profile.gd
scripts/surface_story/surface_story_texture_factory.gd
scripts/surface_story/surface_story_director_3d.gd
```

The texture factory creates small deterministic runtime `ImageTexture` sets. No generated artwork or imported decal atlas is required for v1.

## Surface vocabulary

V1 publishes six reusable surface languages:

- `crack` — structural stress / fractured masonry;
- `moss` — shade, joints, persistent dampness, biological takeover;
- `wet` — runoff, splash zones, stream/basin margins;
- `grime` — age, low masonry, sheltered dirt accumulation;
- `wear` — foot traffic and repeated use;
- `carving` — faded human-made markings protected from the worst erosion.

Each language has an albedo/alpha mask plus an ORM texture so decals can alter perceived roughness/occlusion as well as color.

## Ownership boundary

Surface Story may:

- project visual detail with native `Decal` nodes;
- darken or brighten local albedo;
- modify decal ORM response;
- use shallow floor/wall projection volumes;
- distance-fade decorative stamps;
- expose deterministic debug counts and A/B toggles.

Surface Story must not:

- alter collision;
- alter mesh topology;
- create gameplay statuses or hazards;
- decide whether a surface is slippery/burnable/conductive;
- replace the material/reaction system;
- stamp moving actors as a gameplay effect.

Gameplay surface semantics remain owned by the existing receiver/status/material systems.

## Green Grotto causal grammar

Green deliberately uses a causal rule instead of uniform dressing:

```text
traffic + stress + water + shade + age + human history
```

### Arrival

Light wear and edge grime establish that the approach has been traveled without making the first meters visually noisy.

### Fractured causeway

Every major causeway slab receives structural cracking plus traffic wear. Moss only appears on selected joints/margins.

### Waterfall geography

Wetness is concentrated around the upper stream, waterfall runoff, and lower-basin banks. This reinforces the localized-water geography rather than making the entire grotto look soaked.

### Shrine

The shrine carries the richest history layer: central path wear, moss/grime at outer courses, worn stair treads, protected rear-wall carvings, and lower-wall grime.

### Secondary ruins

The leaning monolith retains a few faded marks, while the side terrace receives limited moss. Secondary landmarks remain visually subordinate to the shrine.

## Runtime procedural textures

The v1 texture factory builds 128×128 RGBA masks at startup and caches one texture set per surface language. Green therefore generates six texture sets once, then all eighty authored stamps reuse them.

This is a bridge technology. Production art can later replace any generated texture set with authored decal textures without changing the placement grammar or Director API.

## Performance contract

Green v1 uses eighty decals, all with:

- shallow projection depth;
- normal-angle fade;
- camera-distance fade;
- cached shared textures.

The goal is concentrated medium/small detail rather than giant screen-filling decals.

## Benchmark hotkeys

The Green Grotto art target now exposes a four-key visual A/B strip:

```text
F4  Surface Story ON/OFF
F5  Environmental Motion ON/OFF
F6  Camera Director ON/OFF
F7  Lighting quality tier
```

This makes it possible to isolate each presentation multiplier on the same geometry.

## Validation

```text
res://scenes/tests/surface_story_director_smoke_test.tscn
```

The regression verifies:

- exactly eighty Green stamps;
- the expected distribution across crack/moss/wet/grime/wear/carving;
- area-level story weighting;
- native Decal nodes and bounded projection volumes;
- distance/normal fading;
- six cached procedural texture sets with visible alpha data;
- F4 hides and restores the complete detail layer without touching geometry.
