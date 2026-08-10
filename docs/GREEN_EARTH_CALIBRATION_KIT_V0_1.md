# Green Earth Calibration Kit v0.1

## Purpose

Green Earth is the first environment kit built under:

```text
GLOBAL_ART_BIBLE_V0_1.md
ENVIRONMENT_ASSET_PRODUCTION_CONTRACT_V0_1.md
```

Its job is **not** to finish the Green dungeon. Its job is to prove the global art direction with a tiny set of authored-replacement modules inside the existing playable shrine blockout.

The current module scenes contain deliberately simple Godot placeholders. Their `Visual` seam is where authored Blender / GLB assets will replace them later.

---

# Visual Thesis

> Monumental wet canyon forms frame a clear stone pilgrimage route toward an ancient Chinese-inspired shrine. Cool, saturated blue-green shadow gives the environment physical depth while restrained warm gold light concentrates attention on sacred architecture. Nature feels old and persistent, but never obscures traversal.

This is a **Green Earth dialect**, not a global palette prescription.

---

# Global Bible Principles Under Test

Green specifically tests whether the global style can deliver:

- readable composition at third-person gameplay distance;
- large forms before detail;
- stylized geometry with believable physical weight;
- saturated but grounded color;
- cool/warm focal contrast;
- clean Grace silhouette against richer environments;
- material identity before texture noise;
- monumentality without clutter;
- restrained ecological dressing;
- focal detail concentrated at the destination.

---

# Calibration Composition

The active Green Grotto visual lab now assembles the kit as:

```text
4 cliff modules
8 route slabs
1 shrine platform
1 shrine stair
4 shrine columns
1 shrine back wall
2 structural beams
2 roof segments
6 bracket placeholders
2 lantern placeholders
4 fern clusters
```

Total placed module instances: **35**.

The older procedural visual studies remain in the scene tree for reference and systems compatibility but are hidden. Existing gameplay collision remains authoritative.

---

# Kit Modules

| Module ID | Category | Target Size (m) | Pivot | First Art Question |
|---|---|---:|---|---|
| `green_cliff_a` | Terrain | 6 × 10 × 12 | ground center | How faceted vs natural should common canyon rock be? |
| `green_cliff_b` | Terrain | 7 × 12 × 14 | ground center | How monumental can background rock become without becoming noisy? |
| `green_path_slab_a` | Traversal | 5.4 × 0.24 × 3.5 | ground center | How broad / stylized should primary traversal stone be? |
| `green_path_slab_b` | Traversal | 4.2 × 0.24 × 2.15 | ground center | How much irregularity can the path support while staying readable? |
| `green_shrine_platform` | Architecture | 11.6 × 1.25 × 8.2 | ground center | What makes sacred masonry feel monumental rather than blocky? |
| `green_shrine_stair` | Architecture | 6.2 × 1.5 × 4 | ground center | How much age and asymmetry can stairs carry without harming traversal read? |
| `green_shrine_column` | Architecture | 0.9 × 4.2 × 0.9 | ground center | How stylized should proportions and carved rhythm become? |
| `green_shrine_beam` | Architecture | 8.2 × 0.42 × 0.56 | center | What is the timber shape language and bevel treatment? |
| `green_shrine_roof` | Architecture | 10.4 × 0.42 × 3.6 | center | What roof silhouette defines Green at long distance? |
| `green_shrine_bracket` | Architecture | 0.9 × 0.55 × 0.75 | center | How much ornament belongs in medium-scale repeated structure? |
| `green_shrine_wall` | Architecture | 7.4 × 3.6 × 0.45 | ground center | How quiet should a focal backdrop remain before emblem / carving detail? |
| `green_lantern` | Prop | 0.42 × 0.72 × 0.42 | ground center | How do small warm accents read against cool surroundings? |
| `green_fern_cluster` | Ecology | 1.8 × 1.1 × 1.8 | ground center | How painterly / graphic should prehistoric vegetation become? |

---

# Shape Language

## Terrain

- broad, tall canyon masses;
- clearly eroded but not covered in small spherical breakup;
- strong vertical framing;
- large planar changes should carry most of the silhouette;
- secondary fractures support the silhouette rather than replacing it.

## Traversal

- wide, low stone masses;
- irregular perimeter, simple upper read;
- subtle height / rotation variation;
- route remains visually continuous from Grace to landmark.

## Shrine

- strong horizontal roof silhouette contrasting vertical canyon walls;
- large platform and stair hierarchy;
- sturdy columns rather than needle-thin supports;
- timber structure reads in layers;
- ornament clusters around brackets, entrances, sacred panels, and focal emblem;
- common surfaces remain quieter.

## Ecology

- plants appear in deliberate pockets;
- broad leaf silhouettes before leaf texture;
- no centerline scatter that muddies traversal;
- natural forms soften architecture and stone edges rather than carpeting every surface.

---

# Palette Roles

Do not treat this as a universal palette.

```text
Dominant shadow:      deep blue-green / charcoal teal
Primary terrain:      cool dark gray-green stone
Supporting natural:   moss, jade, muted emerald
Architecture neutral: warm aged stone / dark timber
Primary focal light:  amber-gold
Water accent:         saturated but deep teal/cyan
Rare accent:          lotus pale pink / sacred turquoise if needed
Grace:                cream + gold remains visually protected
```

Saturation peaks in:

- water;
- selected vegetation;
- magical/sacred accents;
- focal lighting.

Large rock and common architecture stay comparatively quiet.

---

# Material Targets

## Canyon Rock

- physically heavy;
- mostly rough, with localized wet sheen;
- broad color variation rather than speckled noise;
- moss collects in ledges, cracks, and waterline transitions;
- silhouette remains more important than surface normal detail.

## Path Stone

- slightly warmer/readable than canyon walls;
- wetness creates selective specular highlights;
- large cracks and chipped edges are valuable;
- avoid a tiled-floor pattern.

## Shrine Masonry

- more controlled and intentional than natural rock;
- warmer neutral value;
- carved detail reserved for focal surfaces;
- weathering follows joints, bases, roof runoff, and age logic.

## Timber

- deep aged brown;
- broad directional grain;
- warm response under amber light;
- readable bevels at gameplay distance.

## Roof

- dark silhouette first;
- tile rhythm visible in medium forms, not thousands of tiny ridges;
- moss / wetness allowed at edges and drainage zones.

## Vegetation

- large leaf groupings;
- saturated but controlled green families;
- simple material response with subtle translucency only if it materially improves the scene.

---

# Lighting Target

The concept direction is built on a simple hierarchy:

```text
cool dark canyon frame
→ readable neutral route
→ warmer shrine architecture
→ brightest amber focal center
```

Rules:

- the shrine should not need bloom spam to become the destination;
- Grace stays readable without a giant personal spotlight;
- wet stone may catch selective warm highlights;
- environmental fill remains cool enough to preserve warm/cool separation;
- fog and particles stay off or minimal while judging modules.

---

# First Authored Modeling Order

Do **not** model all thirteen modules simultaneously.

Start with five assets that answer the biggest style questions:

1. `green_cliff_a`
2. `green_path_slab_a`
3. `green_shrine_column`
4. `green_shrine_roof`
5. `green_fern_cluster`

These five span terrain, traversal, architecture, silhouette, material language, and ecology.

Once those work in Godot, add:

6. `green_shrine_platform`
7. `green_shrine_beam`
8. `green_shrine_wall`
9. `green_lantern`
10. `green_shrine_bracket`

Then build the variations / support pieces.

---

# Blender Handoff Checklist

For each first-pass model:

- author in meters;
- use the exact target dimensions as the starting bounding box;
- preserve the declared pivot policy;
- export GLB to `art/models/environment/green_earth/<module_id>.glb`;
- keep calibration collision external;
- avoid baking scene-specific lighting into textures;
- keep material slots within the global contract;
- prioritize silhouette and broad planes;
- do not add micro-decoration until the module succeeds in the live camera.

Then assign the imported scene to the wrapper's `authored_visual_scene` field. The level placement should not move.

---

# Acceptance Test

The kit passes v0.1 when the Green shrine approach can be played with the first authored modules and:

- Grace, route, and shrine remain readable immediately;
- the canyon feels monumental rather than boxy;
- stone looks physically grounded without photoreal noise;
- color feels richer than grim realism but less toy-like than a cartoon palette;
- shrine geometry feels stylized but architecturally intentional;
- environmental detail is concentrated instead of uniformly distributed;
- authored assets look coherent under the existing lighting director;
- no gameplay collision or traversal behavior had to be rewritten to accommodate the art.

Only after this test passes should Green Earth expand into a production asset library.
