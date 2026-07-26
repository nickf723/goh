# Route Familiarity v1

Run the regional map:

```text
scenes/levels/prototypes/prototype_regional_expedition_map_v1.tscn
```

## Purpose

Route Familiarity turns the regional expedition network into a gameplay system. The selected connection, its familiarity state, and its saved route seed now determine the expedition that is assembled.

The shared flow is:

```text
Regional node selection
→ Route familiarity plan
→ Segment slice and modifiers
→ Full pre-assembly
→ Expedition crossing
→ Familiarity and seed advancement
```

## True route slices

The three regional connections no longer place Grace inside one full five-segment route.

### Cypress Field Camp ↔ Blue Ridge Waystation

- Normal: Cypress Basin, Wet Woodland, Pine Ridge, Rocky Foothills, Mountain Forest
- Stabilized: Cypress Basin, Pine Ridge, Mountain Forest

### Cypress Field Camp ↔ Old Survey Cairn

- Normal: Cypress Basin, Wet Woodland
- Stabilized: Wet Woodland only

### Old Survey Cairn ↔ Blue Ridge Waystation

- Normal: Pine Ridge, Rocky Foothills, Mountain Forest
- Stabilized: Pine Ridge and Mountain Forest

Reverse travel uses the same connection and places Grace at the selected origin endpoint.

## Familiarity states

```text
Unknown → Discovered → Crossed → Mapped → Stabilized
```

### Discovered

- Full route slice
- Highest obstacle density
- Full enemy camp population
- Uncertain role preview
- Slightly reduced resource availability

### Crossed

- Lower threat and obstacle density
- A known shelter is guaranteed when the route has no authored rest segment
- Preview identifies known segment roles

### Mapped

- Exact segment roles appear before departure
- Route markers appear through the assembled Wilds
- Enemy presence and obstacle density fall further
- Resource opportunities improve

### Stabilized

- The route uses its shortened connector slice
- Hostile camps are mostly cleared or abandoned
- Obstacles are reduced substantially
- Resource availability is highest
- Stabilized-route markers make the safe path visible

## Per-route seeds

Each connection stores its own:

- Generation seed
- Journey index
- Crossing count
- Familiarity state
- Last destination
- Last assembled plan signature

Completing a crossing advances that route's seed. Revisiting a connection therefore produces a new expedition while preserving familiarity and regional discoveries.

## Pre-departure preview

The regional map displays the executable expedition recipe before launch:

- Biome sequence
- Known or exact segment roles
- Expected segment count
- Danger label
- Familiarity effects
- Crossing count

The preview and route generator use the same `RouteFamiliarityPlanner`, preventing the map from promising one journey while assembling another.

## Runtime architecture

- `route_familiarity_planner.gd` creates deterministic route recipes.
- `regional_expedition_store.gd` persists route seeds and familiarity.
- `controller_regional_expedition_map.gd` previews and packages the selected recipe.
- `safe_expedition_route_generator.gd` assembles only that recipe's segment slice.
- `familiarity_expedition_segment_3d.gd` applies familiarity-driven enemies, obstacles, shelters, markers, and resources.

Serialized plan arrays are ordinary Variant arrays rather than typed local arrays. This keeps recipes intact when they cross Dictionary, metadata, and scene boundaries.

## Automated coverage

```text
scenes/tests/route_familiarity_smoke_test.tscn
```

The focused route test verifies:

- All six normal and stabilized route slices
- Deterministic route signatures
- Per-route seed advancement
- Full main-route assembly
- Cypress-to-Cairn assembly
- Stabilized Cairn-to-Blue-Ridge assembly
- Correct segment IDs in every live assembly

The existing Wilds generation and scene boot tests remain separate regressions.

## Current limitation

The older all-in-one regional map persistence smoke test still fails in headless CI after the route recipe assertions, despite the planner and live route assemblies passing independently. Treat that test as unresolved harness debt rather than a green validation claim. Manual testing should cover map selection, launch, arrival, map return, and repeated crossings before this system becomes release-critical.
