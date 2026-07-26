# Wilds Expedition v1

Run:

```text
scenes/levels/prototypes/prototype_wilds_expedition_v1.tscn
```

## Prototype route

The neutral development route connects **Cypress Field Camp** to **Blue Ridge Waystation** through one fully assembled continuous level:

1. Flooded Cypress Basin
2. Wet Woodland Fork
3. Longleaf Pine Ridge
4. Rocky Foothill Camp
5. Blue Ridge Mountain Forest

The Wet Woodland Fork contains an optional side path to the **Old Survey Cairn**.

## Controls

- **F8:** Return Grace to Cypress Field Camp without changing the route.
- **F9:** Rebuild the expedition from the saved seed. The layout should remain identical.
- **F10:** Generate a new route seed and reassemble the wilds. Persistent discoveries remain recorded.
- **Interact:** Record the survey cairn, arrive at Blue Ridge Waystation, and complete the return crossing at Cypress Field Camp.

## Full pre-assembly

`ExpeditionRouteGenerator` loads or creates a route record before Grace enters. It resolves the complete segment plan, instantiates all main-path segments, aligns their sockets, attaches the optional branch, validates the chain, and only then places Grace at the starting camp.

Each segment has:

- A standard entry socket
- A standard main exit socket
- An optional side-branch socket
- A footprint and elevation delta
- Biome, role, boundary, obstacle, water, and color metadata
- Natural blocking boundaries made from forest, marsh, cliff, or mixed geography

## Segment roles in this slice

- **Traversal:** Cypress stepping-stone crossing
- **Discovery:** Wet woodland ruins and side branch
- **Resource:** Pine ridge gathering grove
- **Combat:** Rocky foothill enemy camp
- **Rest:** Mountain forest campsite

## Persistence

The expedition stores a separate prototype record at:

```text
user://expedition_cypress_blue_ridge.json
```

The record contains:

- Route ID
- Generation seed
- Ordered segment IDs
- Per-segment seeds
- Segment turn angles
- Recorded landmarks
- Forward and round-trip completion
- Shortcut state

Rebuilding with F9 reuses the same route signature. F10 changes the seed and route plan but preserves the Old Survey Cairn discovery.

## Current scope

This slice proves the expedition architecture, continuous socket assembly, biome gradient, natural boundaries, seeded regeneration, optional branches, persistent discoveries, endpoint progression, and a return crossing.

It does not yet include a route-selection world map, authored segment scene libraries, navigation validation, weather populations, supply consumption, or save-anywhere player position restoration.

## Automated coverage

```text
scenes/tests/wilds_expedition_smoke_test.tscn
```

The smoke test verifies:

- Five main-path segments assemble
- The optional branch and markers exist
- Every main socket aligns
- Rebuilding preserves the route signature
- The cairn discovery persists
- A new seed changes the route signature without erasing discoveries
