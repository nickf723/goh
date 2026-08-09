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
- surface-contact density;
- final-image MSAA / debanding / specular-aliasing policy.

## Whole-stack presets

```text
F9  BASELINE → BALANCED → HERO
F10 Benchmark HUD ON/OFF
F11 Five-second performance capture
```

The benchmark HUD starts hidden so normal play and screenshot review show the production presentation. F10 restores the full renderer telemetry whenever it is needed.

### BASELINE

- F1-F6 presentation systems off;
- Lighting/Shadow quality = Performance;
- no local reflection probes;
- no atmospheric mote fields;
- Grace uses the exact original material resources;
- Surface Contact emits no extra pieces;
- Performance visual-LOD ranges remain active as the renderer-performance baseline;
- raw final image: no TAA, 3D MSAA, extra screen AA, or debanding;
- the new ambient fauna actor layer is disabled and the original simple `GreenGrottoFaunaVisual` patrol animator regains authority.

### BALANCED

- F1-F6 on;
- ambient fauna acting on;
- Lighting/Shadow quality = Balanced;
- three local reflection probes;
- roughly 12 visible entrance/canopy/waterfall atmosphere instances;
- Balanced Grace material variants;
- Balanced detail visibility ranges;
- three contact pieces per footstep and seven per landing;
- non-temporal 2x 3D MSAA + debanding + screen-space roughness limiting.

### HERO

- all presentation systems on;
- ambient fauna acting on;
- Lighting/Shadow quality = Cinematic;
- all four reflection regions;
- roughly 24–25 visible atmosphere instances across all four authored fields;
- Cinematic Grace skin/hair/cloth/metal/leather presentation;
- longest visual-LOD ranges;
- five contact pieces per footstep and eleven per landing;
- non-temporal 2x 3D MSAA + debanding + stronger screen-space roughness limiting.

The Green Grotto no longer uses TAA in Balanced or HERO. Camera motion was producing enough temporal softness to read as motion blur, so the current art target favors crisp geometry and stable presentation over temporal accumulation.

Manual F1-F7 changes are still supported. Once a named preset no longer matches, the benchmark HUD reports `CUSTOM`.

## V4 readability composition

The V3 hero pass proved the procedural geometry/material vocabulary, but the assembled entrance became too uniformly dense. V4 is deliberately subtractive and protects one visual hierarchy:

```text
Grace → broad route stones → shrine
```

The composition pass:

- visually retires the dense arrival/causeway micro-pavers while retaining their underlying collision scaffolds;
- removes repeated edge rubble and ecology stones from the primary shot;
- culls foliage that enters the central travel corridor while preserving lush side pockets;
- thins the dense foreground chasm-rock wall into a smaller set of framing masses;
- reduces the arrival perimeter rocks;
- replaces the tiled route read with five broad arrival stones plus one broad route stone per causeway segment;
- adds one restrained warm shrine focus light so the destination remains legible through the grotto.

This is a presentation-only composition pass. Traversal, collision, water geography, fauna, and gameplay systems remain unchanged.

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
- final image mode (`RAW` or `2x MSAA` for the current Green presets);
- Grace material quality tier;
- current footstep contact-piece budget;
- ambient fauna actor state.

The overlay is not part of the production HUD and starts hidden by default.

## Readability atmosphere contract

Green still authors 460 deterministic atmosphere candidates, but only a small subset is rendered at once:

```text
Performance   0%
Balanced      3% on Balanced-eligible fields
Cinematic     5% on all fields
```

The atmosphere director reserves a `2.0 m` clear radius around the active gameplay camera and fades motes back in over the next `2.5 m`. Nearby billboards therefore cannot dominate Grace, the route, or the destination.

## Recommended visual test route

Use HERO for the first unstructured playthrough, then repeat the same observations with F9 presets.

### Arrival shelf

Watch for:

- a clear first read of Grace and the primary route;
- only a few large framing rock masses rather than an unbroken wall of boulders;
- broad route stones rather than a tiled-floor grid;
- sparse dust motes and dry foot contacts;
- nearby foliage reacting physically when Grace brushes through it;
- no large atmosphere billboard crossing the immediate camera bubble.

### Canopy / causeway

Watch for:

- the route remaining visually continuous toward the shrine;
- transmitted sunset light through foliage;
- sparse pollen revealing air volume and visual wind without obscuring the route;
- side vegetation reading as clusters instead of centerline scatter;
- shadow grounding on Grace, roots and paving;
- crisp thin leaves and railings while the camera moves in Balanced/HERO.

### Waterfall

Watch for:

- directional waterfall material rather than translucent ribbons;
- refraction/depth tint/shoreline response on horizontal water;
- cool local reflection capture;
- localized mist and damp foot/landing presentation;
- stable water and geometry edges without temporal smearing;
- motion wind affecting mist and nearby vegetation without inventing gameplay force.

### Shrine court

Watch for:

- the shrine reading as the destination before its small details are noticed;
- authored surface history and carved motifs;
- local reflection and shadow response on roof/trim/Grace;
- leaf-litter contact pieces;
- subtle Cinematic-only warm motes;
- stable thin roof/railing edges and Grace gold highlights.

## Performance comparison routine

For useful F11 measurements, keep camera position, viewing direction, resolution and gameplay state fixed.

Recommended sequence:

```text
F10 if benchmark telemetry is needed
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
- the camera readability bubble only changes presentation scale;
- V4 route stones and visual retirement do not change the collision scaffolds beneath them;
- wet decals or damp contact mist do not make a surface slippery;
- foliage interaction can bend presentation transforms but never collision;
- reflection regions describe image-based lighting volumes, not gameplay rooms;
- visual LOD can cull detail rendering but never collision or progression geometry;
- ambient fauna acting does not create combat AI or navigation state;
- Image Fidelity changes the benchmark viewport's final rendering policy but restores the pre-lab state when Green exits.

## Replaceability

Most Green v1 effects are infrastructure, not final assets. Real meshes, textures, animation rigs, particles and authored audio should eventually replace the procedural content while preserving these systemic contracts wherever they remain useful.
