# Grace of Humanity Art Bible v0.2

## Purpose

This document defines a producible visual target for the first art vertical slice. It is a working production guide, not a declaration that every temporary asset is final.

## North star

Grace of Humanity should feel like an inviting mythic adventure built inside an ancient, weighty world.

The visual balance is:

- readable silhouettes before surface detail;
- stylized construction before realism;
- selective ornament before visual noise;
- color-coded magic before neutral effects;
- solemn spaces warmed by human-scale light;
- handcrafted irregularity without requiring photoreal assets.

## Shape language

### Friendly and human

Grace, allies, beds, shrines, and safe spaces use:

- rounded corners;
- broad readable curves;
- layered cloth shapes;
- asymmetry in small accessories;
- visible warm accents.

### Church and judgment

The Church Trial uses:

- tall vertical forms;
- repeated arches;
- thick stone masses;
- recessed panels;
- narrow gold trim;
- violet voids and blue-violet magical light;
- circles and halos as trial motifs.

### Threats

Enemies and hostile machinery use:

- forward-leaning shapes;
- broken symmetry;
- harder corners;
- compressed silhouettes;
- glowing cores or readable attack anchors.

## Character proportions

The early-game Grace model should read as roughly 10–13 years old without becoming chibi.

Target proxy proportions:

- approximately 5.5 to 6 heads tall;
- head slightly larger than an adult heroic model;
- narrow shoulders;
- short forearms and lower legs;
- robe widening toward the floor;
- hands and feet slightly enlarged for gameplay readability;
- hair silhouette visible from the default camera distance.

Faces should remain simple at gameplay distance. Eye direction, brows, and mouth should be readable through shape and value, not skin pores or dense facial geometry.

## Grace v1 palette

- Skin: warm medium tan with neutral undertone.
- Hair: very dark brown, nearly black, with soft warm highlights.
- Main robe: weathered cream rather than pure white.
- Secondary cloth: muted violet.
- Trim: restrained antique gold.
- Boots and utility pieces: deep brown.
- Magic accents: element-specific and brighter than costume colors.

Grace should not look iridescent or technology-covered. Her starting outfit is practical exploration clothing with a quiet mythic identity.

## Material language

### Stone

- Roughness: high.
- Value: dark charcoal to warm gray.
- Variation should come from large painted patches, edge wear, and inset panels.
- Avoid noisy micro-surface detail in early assets.

### Cloth

- Broad matte color blocks.
- Slightly lighter edges and folds.
- One major cloth color plus one secondary accent.
- No metallic cloth except tiny ceremonial details.

### Metal

- Gold is reserved for sacred structure, rewards, and authority.
- Iron and armor should be dark and desaturated.
- Magical metal may carry emissive seams, not full-body glow.

### Magic

- Emission should identify function.
- Glows require a darker surrounding value to remain legible.
- Avoid making every magical object equally bright.
- Use a bright core, medium halo, and dark supporting structure.

## Detail density

Use three reading distances:

1. **Far silhouette**: the object is identifiable by outline and proportion.
2. **Gameplay distance**: one or two major material regions and functional details are visible.
3. **Close inspection**: a few engraved lines, seams, chips, or accessories reward attention.

Do not spend production time on details that disappear from the normal camera.

## Modular environment rules

Church pieces should snap to a practical grid and remain reusable.

Recommended base dimensions:

- wall bay: 4 m wide;
- doorway: 3–4 m wide;
- pillar footprint: about 1 m;
- trim thickness: 0.1–0.25 m;
- floor border: 0.3–0.6 m;
- room height target: 5–8 m even when gameplay collision remains lower.

Visual-only kit pieces must not add collision unless their scene is explicitly designed as a gameplay blocker.

## Asset budgets for the vertical slice

These are targets, not rigid technical limits.

### Grace proxy

- Primitive or low-poly assembled model now.
- Future production target: 15k–35k triangles for the gameplay model.
- One 2k material set is sufficient for the first production pass.
- Reusable humanoid skeleton.

### Common enemies

- Future target: 8k–25k triangles.
- One primary material set.
- Strong attack and status anchors.

### Animated Armor boss

- Future target: 25k–60k triangles.
- Separate weapon and emissive core regions.
- Large readable armor plates rather than dense filigree.

### Church kit

- Most modular pieces: under 5k triangles.
- Hero altar or gate pieces: under 15k triangles.
- Shared material library preferred over unique textures per piece.

## Lighting

The Church Trial lighting stack should use:

- low cool ambient light;
- warm local lights at safe or sacred points;
- violet fill in deep spaces;
- gold highlights on important thresholds;
- restrained fog or atmosphere later, after navigation remains readable.

Gameplay targets, enemies, exits, and hazards must remain identifiable without relying only on bloom.

## VFX language

- Fire: turbulent warm core, darker smoke edge.
- Water: transparent body, bright moving rim.
- Sound: expanding rings, line echoes, temporary outlines.
- Space/Violet: deep interior, sharp luminous edge.
- Save and healing: calm cyan or pale gold, slow pulse.
- Trial completion: gold with a small rainbow or multi-element accent only when narratively appropriate.

## Replacement philosophy

Prototype art should be built behind stable wrapper nodes.

A future imported `.glb` should replace the contents of `VisualRoot` or a visual scene without changing:

- collision;
- player controller;
- camera;
- interaction areas;
- ability caster;
- weapon controller;
- receivers;
- save data;
- puzzle logic.

## Current v0.2 visual target

The first pass is successful when:

- Grace is recognizably a young robed explorer rather than a capsule;
- the Church entry has arches, pillars, trim, braziers, and layered light;
- the room still plays exactly as before;
- every new visual can later be replaced without rewriting gameplay.
