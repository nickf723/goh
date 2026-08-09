# Green Grotto Visual Lab v1

## Purpose

The Green Grotto art target is the project's shared renderer and presentation benchmark. It deliberately keeps the current procedural geometry while exercising the systems that can improve perceived quality before dedicated modeling and texture authoring become the next bottleneck.

Primary scene:

```text
res://scenes/levels/prototypes/prototype_green_grotto_art_target_v1.tscn
```

## Independent controls

```text
F1  Vegetation Presentation ON/OFF
F2  Water Presentation ON/OFF
F3  Material Fidelity ON/OFF
F4  Surface Story ON/OFF
F5  Environmental Motion ON/OFF
F6  Camera Director ON/OFF
F7  Renderer quality: Performance → Balanced → Cinematic
```

F5 includes ambient visual wind, real Airflow response, Grace accessory wind, and Grace-to-foliage/vine interaction.

F7 is the shared quality spine. It controls more than Lighting Director itself:

- SDFGI / SSIL / SSR / volumetric fog;
- directional and local shadow fidelity;
- local ReflectionProbe budget;
- atmospheric mote density;
- Grace material quality;
- environment detail visibility ranges;
- surface-contact density.

## Whole-stack presets

```text
F9  BASELINE → BALANCED → HERO
F10 Benchmark HUD ON/OFF
F11 Five-second performance capture
```

### BASELINE

- F1-F6 presentation systems off;
- Lighting/Shadow quality = Performance;
- no local reflection probes;
- no atmospheric mote fields;
- Grace uses the exact original material resources;
- Surface Contact emits no extra pieces;
- Performance visual-LOD ranges remain active as the renderer-performance baseline;
- the new ambient fauna actor layer is disabled and the original simple `GreenGrottoFaunaVisual` patrol animator regains authority.

### BALANCED

- F1-F6 on;
- ambient fauna acting on;
- Lighting/Shadow quality = Balanced;
- three local reflection probes;
- reduced-density entrance/canopy/waterfall atmosphere;
- Balanced Grace material variants;
- Balanced detail visibility ranges;
- three contact pieces per footstep and seven per landing.

### HERO

- all presentation systems on;
- ambient fauna acting on;
- Lighting/Shadow quality = Cinematic;
- all four reflection regions;
- all 460 authored atmosphere instances;
- Cinematic Grace skin/hair/cloth/metal/leather presentation;
- longest visual-LOD ranges;
- five contact pieces per footstep and eleven per landing.

Manual F1-F7 changes are still supported. Once a named preset no longer matches, the benchmark HUD reports `CUSTOM`.

## Benchmark HUD

The Green scene installs a development-only `VisualBenchmarkDirector` overlay. It reports:

- matched preset;
- rolling FPS and frame time;
- draw calls;
- rendered primitives;
- F1-F6 state;
- F7 renderer tier;
- active reflection-probe count;
- visible atmosphere-instance count;
- managed visual-LOD target count;
- Grace material quality tier;
- current footstep contact-piece budget;
- ambient fauna actor state.

The overlay is not part of the production HUD.

## Recommended visual test route

Use HERO for the first unstructured playthrough, then repeat the same observations with F9 presets.

### Arrival shelf

Watch for:

- sheltered/cool lighting transition;
- dust motes and dry foot contacts;
- nearby foliage reacting physically when Grace brushes through it;
- the arrival raptor watching Grace before retreating at close distance.

### Canopy / causeway

Watch for:

- transmitted sunset light through foliage;
- pollen revealing the air volume and visual wind;
- shadow grounding on Grace, roots and paving;
- material microdetail under grazing light;
- far detail disappearing only once it is no longer useful to the composition.

### Waterfall

Watch for:

- directional waterfall material rather than translucent ribbons;
- refraction/depth tint/shoreline response on horizontal water;
- cool local reflection capture;
- localized mist and damp foot/landing presentation;
- motion wind affecting mist and nearby vegetation without inventing gameplay force.

### Shrine court

Watch for:

- authored surface history and carved motifs;
- local reflection and shadow response on roof/trim/Grace;
- leaf-litter contact pieces;
- subtle Cinematic-only warm motes;
- tighter Camera Director framing.

## Performance comparison routine

For useful F11 measurements, keep camera position, viewing direction, resolution and gameplay state fixed.

Recommended sequence:

```text
F9 until BASELINE
wait 2 seconds
F11
wait for capture completion

F9 → BALANCED
wait 2 seconds
F11
wait for capture completion

F9 → HERO
wait 2 seconds
F11
wait for capture completion
```

The five-second capture records:

- average FPS;
- average frame time;
- estimated 1% low FPS;
- average draw calls;
- average rendered primitives.

The purpose is not to crown HERO automatically. A feature that costs substantial frame time but creates no meaningful visual gain should be tuned down or removed.

## Ownership boundaries

The visual lab deliberately keeps presentation separate from gameplay truth.

Examples:

- atmospheric motes may reveal air movement but cannot create airflow force;
- wet decals or damp contact mist do not make a surface slippery;
- foliage interaction can bend presentation transforms but never collision;
- reflection regions describe image-based lighting volumes, not gameplay rooms;
- visual LOD can cull detail rendering but never collision or progression geometry;
- ambient fauna acting does not create combat AI or navigation state.

## Replaceability

Most Green v1 effects are infrastructure, not final assets. Real meshes, textures, animation rigs, particles and authored audio should eventually replace the procedural content while preserving these systemic contracts wherever they remain useful.
