# Regional Expedition Map v1

Run:

```text
scenes/levels/prototypes/prototype_regional_expedition_map_v1.tscn
```

## Current network

The prototype begins at **Cypress Field Camp** and tracks three persistent regional nodes:

- Cypress Field Camp
- Blue Ridge Waystation
- Old Survey Cairn, hidden until Grace records it inside the Wilds

The initial connection is the full Cypress-to-Blue-Ridge crossing. Discovering the cairn reveals two partial survey connections:

```text
Cypress Field Camp ↔ Old Survey Cairn ↔ Blue Ridge Waystation
```

The direct main crossing remains available between Cypress and Blue Ridge.

## Player loop

1. Select a discovered destination.
2. Review the biome progression, danger, route length, state, and crossing count.
3. Choose **Assemble Expedition**.
4. The existing Wilds scene loads with the selected origin and destination.
5. Grace begins at Cypress Camp, Blue Ridge Waystation, or the Survey Cairn according to the launch record.
6. Interacting with the selected destination updates the regional network and returns to the map.

The map supports mouse and controller navigation. After selecting a destination, controller focus moves directly to the launch action.

## Route progression

Connections advance through:

```text
Unknown → Discovered → Crossed → Mapped → Stabilized
```

Crossings promote route familiarity. The existing Wilds expedition record also promotes the main connection when the forward crossing, round trip, or survey shortcut has already been completed.

## Persistence

The regional network is stored at:

```text
user://regional_expedition_network_v1.json
```

It records:

- Grace's current regional node
- Discovered nodes
- Route states
- Crossing counts
- Last destination for each route

The original generated route continues to use:

```text
user://expedition_cypress_blue_ridge.json
```

The map synchronizes both records so the Survey Cairn and existing crossing progress appear automatically.

## Automated coverage

```text
scenes/tests/regional_expedition_map_smoke_test.tscn
```

The test verifies:

- Cypress is the initial current location
- The cairn begins hidden
- Selecting Blue Ridge resolves the main route
- The map produces a valid Wilds launch context
- The Wilds scene reads that context
- Recording the cairn reveals it in the network
- Reaching Blue Ridge updates current location and route state
- Reloading the map preserves Blue Ridge as the current node
- The newly discovered cairn exposes the Blue Ridge-to-Cairn survey route

## Current limits

- All three connections reuse the same assembled Wilds level.
- Partial survey journeys still assemble the full level, then place Grace at the selected origin marker.
- The map is a standalone prototype scene rather than an in-world table inside a settlement.
- Supplies, weather forecasts, companions, route costs, factions, and alternate segment libraries are not connected yet.
