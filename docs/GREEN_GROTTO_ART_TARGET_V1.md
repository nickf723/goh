# Green Grotto Art Target v1

## Goal

Build one environment slice to a substantially higher visual bar before expanding production VFX or placeholder audio.

The target is the **Green / Earth dungeon** in the Chinese mountains:

- ancient Chinese-inspired ruins isolated inside a mountain grotto;
- technically outdoors, but sealed by an extremely dense canopy;
- saturated prehistoric greens cut by warm orange sunset light;
- cycads, giant ferns, roots, vines, moss, and extinct fauna;
- unstable stone geography, broken causeways, leaning ruins, and deep chasms;
- dinosaurs used as environmental scale and identity rather than combat content.

This pass deliberately prioritizes environment art. Production VFX and production audio remain deferred until the base world reads convincingly.

## Scene

```text
res://scenes/levels/prototypes/prototype_green_grotto_art_target_v1.tscn
```

The playable composition is:

```text
shadowed arrival shelf
        ↓
fractured ruin causeway
        ↓
layered chasm / waterfall / side terraces
        ↓
sunset shrine landmark
```

The player begins in canopy shadow looking toward the warm shrine. The route itself stays relatively readable while cliffs, roots, foliage, ruined columns, and hanging vines provide density around the edges.

## Procedural material target

`scripts/environment/green_grotto_material_library.gd` creates reusable StandardMaterial3D resources backed by NoiseTexture2D + FastNoiseLite color ramps.

Current families include:

- weathered green-brown stone;
- warm sunset stone;
- deep grotto stone;
- moss;
- foliage and sunlit foliage;
- canopy foliage;
- bark and roots;
- aged roof tile;
- aged wood;
- soil;
- water and waterfall ribbons;
- prehistoric fauna materials.

The purpose is not to replace final authored textures. It is to establish material separation, roughness, surface variation, and color relationships now, while remaining entirely code/resource generated.

## Architecture target

The shrine and ruins do not reuse the Weathered Cloister silhouette. The art-target script builds a bespoke vocabulary:

- oversized layered eaves;
- pitched roof planes and ridge;
- timber/stone lintels;
- ceremonial columns with banding;
- carved frieze strips;
- broken gate forms;
- leaning monoliths;
- collapsed masonry;
- fractured causeway slabs;
- elevated terraces.

These are still procedural meshes and should eventually be replaced by authored production assets while preserving their composition and collision footprint.

## Canopy and lighting

The canopy uses actual shadow-casting geometry. The scene relies on a warm low-angle directional sun, cool green fill, modest fog, volumetric atmosphere, SSAO, and restrained glow. There are no new combat-style flash effects in this pass.

The goal is to let orange light emerge through gaps in the canopy rather than painting large fake beams over a graybox.

## Prehistoric fauna

`scripts/environment/green_grotto_fauna_visual.gd` provides lightweight environment-only fauna:

- three small feathered raptor silhouettes;
- one distant sauropod scale landmark.

They use simple procedural body parts and quiet head/tail motion. They are not enemies and own no combat AI.

## Playability support

The causeway, shrine, terraces, stairs, cliffs, and arrival shelf have physical collision. A recovery volume returns Grace to the entrance if she falls into the art-target chasm. Normal spells, Focus, movement, and regenerating lab resources remain available for in-context readability testing.

`F8` / the existing restart action returns Grace to the entrance.

## Promotion boundary

This is an **art target**, not the final Earth dungeon.

Keep:

- color hierarchy;
- shrine focal composition;
- fractured causeway route;
- dense canopy enclosure;
- prehistoric flora/fauna identity;
- warm/cool lighting relationship;
- unstable layered geography.

Replace later:

- primitive-derived architecture with authored Chinese ruin meshes;
- procedural noise surfaces with authored texture/material sets;
- simple foliage meshes with production vegetation and LODs;
- placeholder fauna geometry with final creature models/animation;
- simple waterfall ribbons with final water simulation/presentation.

## Automated contract

```text
res://scenes/tests/green_grotto_art_target_smoke_test.tscn
```

The regression checks the composition contract, environmental density, procedural material library, canopy, waterfall, prehistoric fauna, deferred VFX/audio policy, and core landmark/route nodes.
