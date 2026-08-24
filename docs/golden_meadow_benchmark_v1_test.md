# Golden Meadow Benchmark v1 Manual Test

## Purpose

This scene is the first **single-biome hero-quality gate** for *Grace of Humanity*.

It deliberately contains no enemies, puzzles, interactables, buildings, ruins, loot, route signage, or full gameplay HUD. The only subject is a quiet field:

- one rolling terrain surface with a dedicated heightmap collider, reusable location-ground material, and geometry-backed earth details;
- a short, dense wind-reactive grass canopy;
- restrained seed heads and clustered wildflowers;
- three atmospheric horizon silhouettes;
- a warm low sun, cool sky fill, height fog, and volumetric haze;
- Grace as the human scale and readability reference.

The field should feel like the beginning of a vibrant global adventure, not a systems laboratory or an asset-library collage.

## Load the benchmark

Run with F6:

```text
res://scenes/levels/prototypes/prototype_golden_meadow_benchmark_v1.tscn
```

Controls:

```text
WASD / LEFT STICK     MOVE
MOUSE / RIGHT STICK   CAMERA
SPACE / SOUTH BUTTON  JUMP
C / EAST BUTTON       DODGE
R                     RESET
```

RESET reloads the benchmark and restores the deterministic terrain and vegetation seed.

## 1. First-frame composition

Do not move for ten seconds.

Confirm:

- Grace begins near the southern edge looking across the long dimension of the field;
- the ankle-to-calf foreground canopy frames Grace without hiding her feet or silhouette;
- the terrain rolls are broad enough to read as land rather than vertex noise;
- near, middle, and far ridges hide the finite prototype boundary;
- the low golden sun creates one dominant warm lighting idea;
- cool sky fill keeps shaded grass readable without turning it cyan;
- there are no floating labels, objective panels, props, enemies, or developer consoles competing with the landscape.

The desired first impression is **quiet scale and invitation**.

## 2. Wind and vegetation

Stand still, then rotate the camera slowly through a full circle.

Confirm:

- gusts travel broadly across the meadow instead of making every blade wobble independently;
- taller seed heads bend slightly farther than the main grass canopy;
- per-instance height, orientation, phase, and color variation prevent obvious repetition;
- wildflowers form restrained natural pockets rather than an even confetti distribution;
- the cool rim separates grass silhouettes only at glancing angles;
- warm tip light never becomes a permanent emissive glow;
- grass remains opaque and grounded without alpha-sorting noise.

Watch for synchronized rows, visible scatter grids, flickering triangles, excessive sparkle, or motion that resembles underwater seaweed.

## 3. Ground and contact

Walk north through the center, then make broad loops across both sides.

Confirm:

- Grace's live `player_controller_free_aim_status.gd` path starts in benchmark free-roam mode, resolves onto the heightmap collision surface, and accepts movement immediately;
- Grace follows the visible terrain with no sinking or sudden collision steps;
- irregular domain-warped turf breaks into clearly visible dirt instead of a uniform color wash;
- at least four large geometry-backed dirt patches are obvious in the opening view, with additional deterministic patches distributed across the field and grass excluded from their cores;
- soil carries lighter packed-earth variation and real low-poly pebble scatter at close range;
- procedural relief catches light without changing the collision-matched silhouette;
- the same shader can be retuned by palette, location offset, patch density, slope exposure, pebbles, and optional path controls for later authored sets;
- the grass roots meet the terrain rather than hovering above it;
- rolling elevation changes remain gentle enough for ordinary movement, jumping, and dodging;
- the flattened spawn pocket prevents an awkward opening stance without reading as an artificial platform;
- the invisible safety boundary sits beyond the main composition and never becomes visually apparent.

## 4. Readability at scale

Check Grace from the default camera, during movement, against the sun, and inside cool shadow.

Confirm:

- Grace remains the darkest or clearest moving silhouette in the immediate field;
- the warm/cool split describes depth without recoloring Grace;
- tall grass does not swallow the lower body for long stretches;
- distant ridges separate from one another through value and atmosphere;
- the field still reads when the camera faces away from the sun;
- pollen motes remain a subtle depth cue rather than screen noise.

## 5. Performance pass

Traverse from the spawn vista to every edge while rotating the camera.

Record:

- worst visible frame-rate drop;
- whether shadow quality changes noticeably at distance;
- any vegetation batch popping or incorrect culling;
- any hitch on first load or after RESET;
- whether the 23,000 five-blade grass clumps, 1,550 seed heads, 440 wildflowers, 34 dirt patches, 420 pebbles, volumetric fog, and shadows are acceptable together on the target development machine.

Do not reduce density preemptively. First identify whether grass geometry, shadows, fog, or particle presentation is actually responsible.

## Approval gate

Before this biome language moves into the Wilds Expedition, decide:

1. Is the terrain silhouette natural enough?
2. Is the grass density rich enough without hiding Grace?
3. Do the gusts feel like wind crossing a field?
4. Is the golden-hour palette genuinely beautiful rather than merely saturated?
5. Does the horizon feel expansive without adding landmarks?
6. Which single layer is weakest: ground, grass, atmosphere, horizon, or contact?

Tune the weakest layer in this same benchmark before adding trees, rocks, animals, ruins, weather, or gameplay.

## Automated validation

Registered smoke scene:

```text
res://scenes/tests/golden_meadow_benchmark_smoke_test.tscn
```

It verifies:

- deterministic surface construction and minimum topology;
- a terrain-specialized heightmap collider with sufficient sampling resolution;
- Grace's actual free-aim status controller, benchmark free-roam state, penetration recovery, and real movement;
- grass, seed-head, and wildflower density;
- three horizon layers;
- the reusable organic location-ground shader, assertive meadow preset, tangent basis, geometry-backed dirt patches, pebble scatter, and meadow wind shader;
- per-instance grass variation and enabled wind;
- procedural sky, ACES tonemapping, SSAO, height fog, and volumetric fog;
- warm-key/cool-fill lighting;
- playable-space recovery;
- automatic recovery from a paused launcher/menu session;
- scene-local suppression of Grace's gameplay HUD layers;
- absence of enemies, interactables, and the full gameplay HUD.

## Known limitations

- Geometry, colors, and scatter remain procedural calibration assets; the location-ground shader and meadow detail overlay are reusable prototypes rather than a final authored texture set.
- The benchmark proves one temperate golden-hour meadow, not a universal grass solution.
- Grass does not yet bend around Grace, attacks, animals, or weather forces.
- No weather states or day/night cycle are included; those remain outside this single-look quality gate.
- Final audio, insects, distant birds, and regional ecology are intentionally absent.
- The horizon silhouettes are atmospheric backdrops rather than traversable terrain.
