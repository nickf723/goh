# Grace of Humanity — Environment Asset Production Contract v0.1

## Purpose

This document translates `GLOBAL_ART_BIBLE_V0_1.md` into a production contract for reusable environment kits.

The art bible defines **what the game should look and feel like**. This contract defines **how authored 3D assets enter the game without losing that direction or becoming entangled with gameplay code**.

The core boundary is:

```text
Concept art defines the target.
Blender authors the visual asset.
Godot places, lights, animates, and runs the world.
Blockout collision remains authoritative until an asset earns promotion.
```

Godot primitives are permitted as explicit placeholders. They are not a final modeling workflow.

---

# 1. Asset Hierarchy

```text
Global Art Bible
→ Art Dialect / Location Brief
→ Environment Kit Definition
→ Replacement-ready Module Scene
→ Authored Blender / GLB Visual
→ Godot Level Composition
```

A module exists because a useful visual/structural pattern repeats. A one-off landmark should remain bespoke unless repetition proves that a module is useful.

---

# 2. Canonical Folder Contract

```text
art/models/environment/<dialect>/
    <module_id>.glb

scenes/environment/kits/<dialect>/
    <module_id>.tscn

data/environment_kits/
    <kit_id>.tres

docs/
    <DIALECT_OR_KIT>_CALIBRATION_KIT_V*.md
```

Imported production visuals belong under `art/models`. The `.tscn` wrapper remains the stable scene-level seam used by levels.

---

# 3. Units and Coordinate System

- `1 Godot unit = 1 meter`.
- Blender scenes are authored in meters.
- +Y is up.
- Godot gameplay forward is generally -Z; individual symmetric props do not need a preferred forward direction.
- Do not fix scale problems by arbitrary level-instance scaling once an asset is promoted.

Calibration placeholders may use simple transforms while proportions are still being judged.

---

# 4. Pivot Rules

Every reusable module declares one pivot policy.

### `ground_center`
Use for cliffs, columns, props, plants, stairs, platforms, and freestanding modules. Origin sits at ground level in the horizontal center.

### `center`
Use for beams, roof segments, hanging elements, and pieces primarily positioned relative to another module.

### `edge_center`
Reserved for future wall/floor snap kits where one edge is the canonical grid seam.

Pivots are part of the asset interface. Do not casually move them after a module is in use.

---

# 5. Replacement-Ready Scene Wrapper

Every new calibration module uses `EnvironmentKitModule` as the stable wrapper.

The wrapper owns:

- module identity;
- target dimensions;
- category;
- pivot policy;
- collision policy;
- placeholder status;
- the stable `Visual` child seam;
- the eventual authored `PackedScene` / GLB visual.

A level should place the wrapper, not a raw imported mesh.

This lets an ugly calibration box become a Blender asset without changing level layout code.

---

# 6. Collision Contract

During art calibration, prefer:

```text
collision_policy = external_blockout
```

This means the established gameplay blockout owns traversal and collision while the art module remains visual-only.

Promote collision into the module only when:

- the shape is stable;
- the module is genuinely reused;
- simple collision can match the authored form without creating traversal snags.

Never use render-mesh collision for general environment modules by default.

---

# 7. Shape-Language Contract

Before texture work, every authored module must pass three reads:

1. **Silhouette read** — recognizable against a flat background.
2. **Gameplay-distance read** — useful from the third-person camera.
3. **Composition read** — supports the scene without demanding equal attention to the landmark.

Large and medium forms must do the visual work. Micro-detail cannot rescue a weak silhouette.

---

# 8. Material Contract

Global target: **stylized forms with grounded material response**.

A material must communicate its family before texture detail is inspected:

- stone has mass, roughness, fracture, and believable wet/dry behavior;
- wood shows directional grain logic and age without becoming visual static;
- metal has restrained metallic response and readable oxidation/wear;
- vegetation uses broad value/color grouping before leaf-level noise;
- water supports depth, reflection, movement, and palette contrast without becoming a mirror.

Avoid uniform procedural noise sprayed across every surface.

## Material-slot budget

Provisional calibration target:

- common module: 1–2 material slots;
- focal architectural module: up to 3 when visually justified;
- tiny props should generally remain at 1.

---

# 9. Texture and Surface-Density Contract

Texel density remains provisional until the first authored kit is evaluated in-engine.

Initial target:

```text
large terrain / background forms: ~128–256 px per meter
common architecture:            ~256 px per meter
focal architecture / props:     up to ~512 px per meter where needed
```

Prefer trim sheets, tiling materials, masks, decals, and reusable detail systems over unique high-resolution textures for every module.

Painterly breakup should be readable at gameplay distance rather than optimized for extreme close-up inspection.

---

# 10. Geometry Budget

Do not chase a universal triangle number. Silhouette value matters more than raw count.

Calibration guidance:

- small prop: usually under ~5k triangles at LOD0;
- common structural module: usually under ~15k;
- large terrain or focal architectural module may exceed that when silhouette demands it.

The important question is whether geometry contributes visible form from the gameplay camera.

Do not spend geometry on invisible micro-bevels or texture-like surface noise.

---

# 11. LOD and Visibility

Calibration phase:

- author LOD0 first;
- validate silhouette and material language in the real scene;
- add LOD1 only after the module earns promotion;
- let Godot visibility/LOD systems handle distance policy globally.

Do not build an elaborate LOD chain for a module whose art direction is still unresolved.

---

# 12. Lighting Boundary

Lighting belongs primarily to the level / lighting director, not the mesh.

Modules may include local emissive surfaces or a deliberately reusable prop light, but should not arrive with baked scene mood that fights authored level lighting.

A module must work under:

- cool ambient shadow;
- warm key/focal light;
- overcast/diffuse conditions;
- the location's elemental palette shifts.

---

# 13. Detail Hierarchy

Environment kits must preserve the global hierarchy:

```text
large form
→ medium structural form
→ focal detail
→ surface breakup
→ decals / wear
→ atmosphere / VFX
```

Common modules should usually be quieter than landmarks.

A kit is successful when repeated pieces make a level coherent without making the level look tiled or prefabbed.

---

# 14. Calibration Promotion Gates

A placeholder module becomes an authored candidate only after:

- its dimensions work in the gameplay blockout;
- its repetition is useful;
- its silhouette supports the art dialect;
- its pivot is correct;
- the player camera reads it cleanly.

An authored candidate becomes production-approved only after:

- material response works in multiple lighting conditions;
- Grace remains readable beside it;
- it does not increase navigation confusion;
- performance is acceptable;
- collision behavior is proven if the module owns collision;
- it still obeys the Global Art Bible rather than merely matching one concept image.

---

# 15. Calibration Philosophy

The first kit is not a content-production sprint. It is an experiment that answers:

- How stylized should the geometry be?
- How much realism belongs in the materials?
- How saturated can the palette become without losing weight?
- How much beveling is visible enough?
- How much surface breakup is enough?
- How ornate should focal architecture become relative to common modules?
- How does Grace read beside authored assets?

Only after Green Earth and a strongly contrasting second kit both work should these provisional values harden into production standards.
