# Wilds Expedition v1.1

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

## Live wildlife habitats

The first three route segments now compose the canonical Mob Engine into exploration content:

- **Cypress Basin:** a cautious Goose and Trout share a real current-bearing `SwimmingWaterVolume` in the right-hand channel.
- **Wet Woodland:** a curious Gecko follows a surface route around a mossy climbing snag.
- **Pine Ridge:** a Mole follows a three-dimensional route between two visible openings in a rooted soil mound.

These are the same data-driven species, moves, personalities, perception, vitals, and locomotion executors used by the Animal Behavior Lab. The field host supplies Grace perception, footstep noise, habitat bounds, same-species alerts, and medium restoration. Field animals hide the lab diagnostic labels without creating separate presentation actors.

### Wildlife playtest

1. Start from Cypress Field Camp and enter the flooded basin.
2. Find the Goose and Trout in the right channel. Both should remain in **Swimmer** mode, follow the current, and react when Grace approaches.
3. Continue to Wet Woodland. The Gecko should climb around the mossy snag left of the trail without falling to ground movement.
4. Continue to Pine Ridge. The Mole should travel between the dark burrow openings and change elevation inside the translucent root mound.
5. Press **F9**. The route should rebuild with one copy of each habitat, four total animals, restored movement modes, and no floating debug labels.
6. Press **F10**. The new route seed should preserve the same authored wildlife roles while changing the seeded expedition layout.

The bodies, names, mound transparency, and habitat placement are prototype field presentation. Nick's playtest remains the authority on visibility, pacing, and whether the animals feel naturally placed.

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

This slice proves the expedition architecture, continuous socket assembly, biome gradient, natural boundaries, seeded regeneration, optional branches, persistent discoveries, endpoint progression, a return crossing, and authored field use of shared swimming, climbing, and burrowing animal habitats.

It does not yet include ecological predator/prey loops, field feeding or bonding controls, weather populations, supply consumption, or save-anywhere player position restoration. The regional route-selection map and three authored segment layouts are available through the Regional Expedition Map flow.

## Automated coverage

```text
scenes/tests/wilds_expedition_smoke_test.tscn
```

The Wilds and route-familiarity smoke tests verify:

- Five main-path segments assemble
- The optional branch and markers exist
- Every main socket aligns
- Three compatible habitat hosts create four live animals
- Water, climbing, and burrowing animals begin in their authored modes
- Field animals resolve Grace through the habitat provider and hide laboratory labels
- Rebuilding removes stale habitats before restoring one clean population
- Regional route slices include only the habitats belonging to their selected segments
- Rebuilding preserves the route signature
- The cairn discovery persists
- A new seed changes the route signature without erasing discoveries
