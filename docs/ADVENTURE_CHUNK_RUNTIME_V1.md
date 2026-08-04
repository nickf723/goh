# Adventure Chunk Runtime v1

## Purpose

The Adventure Chunk Runtime turns a large level, dungeon, questline, or regional chapter into self-contained gameplay units with a shared lifecycle.

A chunk can represent:

- a combat encounter,
- a puzzle room,
- a traversal challenge,
- an investigation,
- a rescue,
- a crafting step,
- a dialogue beat,
- a shrine or checkpoint,
- an optional side route,
- or any other mechanic that can report completion.

Chunks are connected through dependency IDs. The resulting structure is a directed graph rather than a hard-coded sequence, so authors can create linear chains, parallel wings, optional branches, and convergence points.

## Core types

### `AdventureChunkDefinition`

A Resource containing authored data:

- stable chunk ID,
- display name and category,
- prerequisite chunk IDs,
- optional or required status,
- automatic or manual activation,
- completion policy,
- persistence flag,
- objectives and messages,
- mana reward,
- and managed-content behavior.

Definitions should live under `res://data/adventure/chunks/`.

### `AdventureChunk`

The runtime lifecycle node.

States:

1. `LOCKED`
2. `AVAILABLE`
3. `ACTIVE`
4. `COMPLETED`
5. `FAILED`

The chunk owns:

- requirement registration,
- requirement progress,
- state transitions,
- objective and message publication,
- completion rewards,
- persistence,
- and activation of managed scene content.

Managed content can be hidden, paused, and stripped of collision while its chunk is locked. Original visibility, process mode, collision layer, and collision mask are restored when the chunk activates.

### `AdventureSignalRequirement`

A compatibility adapter for existing mechanics.

It listens to an authored source node and can complete from:

- a signal,
- a boolean property,
- or both.

It can also call an optional reset method when the sequence resets.

Examples:

| Existing source | Signal | Property |
| --- | --- | --- |
| Mana shrine | `shrine_used` | none |
| Prototype encounter | `encounter_completed` | `encounter_complete` |
| Element lock | `puzzle_completed` | `puzzle_complete` |
| Level exit | `exit_triggered` | `has_triggered` |

### `AdventureSequenceDirector`

The graph authority.

It:

- discovers chunks beneath an authored container,
- validates unique IDs,
- checks missing dependencies,
- detects dependency cycles,
- prevents two chunks from owning the same managed content path,
- activates chunks whose dependencies are complete,
- supports parallel and optional chunks,
- records deterministic completion order,
- persists sequence completion,
- and exposes a complete graph snapshot for tests and debugging.

### `AdventureChunkGate`

A physical dependency barrier.

The gate stays collidable until its required chunk completes. It can be authored or generated at runtime and automatically relocks when the sequence resets.

## Completion policies

### Manual

The chunk completes only when another script explicitly calls `complete_chunk()`.

Useful for:

- narrative decisions,
- multi-system conclusions,
- scripted transitions,
- or chunks whose completion cannot be expressed as one requirement.

### All requirements

Every non-optional requirement must complete.

Useful for:

- multi-target puzzles,
- encounters with a follow-up interaction,
- compound rescues,
- or rooms with several independent goals.

### Any requirement

The first completed requirement resolves the chunk.

Useful for:

- alternate puzzle solutions,
- multiple traversal routes,
- stealth versus combat branches,
- or sandbox challenges where any valid method should count.

## Example graph

The chunked prototype mini-dungeon is authored as:

```text
Prepare at Shrine
        ↓
Clear Combat Chamber
        ↓
Solve Element Lock
        ↓
Reach Exit
```

Its definitions are stored in:

```text
res://data/adventure/chunks/mini_dungeon_prepare.tres
res://data/adventure/chunks/mini_dungeon_combat.tres
res://data/adventure/chunks/mini_dungeon_element_lock.tres
res://data/adventure/chunks/mini_dungeon_exit.tres
```

The playable chunked scene is:

```text
res://scenes/levels/prototypes/prototype_mini_dungeon_chunked_v1.tscn
```

The legacy mini-dungeon remains untouched while the chunked version is validated.

## Branching example

```text
Arrival Investigation
      ├── Rescue Juniper (optional)
      ├── Search Herbalist Garden (optional)
      └── Village Square Combat
                    ├── Ice Bridge Route
                    └── Debris Route
                              ↓
                       Church Approach
```

Optional chunks can activate beside the main route, save their own completion, and appear in graph/debug summaries without blocking required progression.

## Authoring recipe

1. Create one `AdventureChunkDefinition` per gameplay unit.
2. Give every chunk a stable ID that will not change with scene-node names.
3. List prerequisite IDs in `required_chunk_ids`.
4. Add an `AdventureChunk` node beneath the sequence's chunk container.
5. Assign managed content paths if the chunk owns a room or mechanic subtree.
6. Add one or more `AdventureSignalRequirement` children.
7. Point each requirement at an existing signal/property source.
8. Add an `AdventureSequenceDirector` and bind it to the level root.
9. Add `AdventureChunkGate` barriers only where physical progression needs enforcement.
10. Add a graph regression that completes the sequence without player input.

## Save behavior

Each definition produces a completion flag. An explicit flag can be authored, or the runtime derives:

```text
adventure_chunk_<chunk_id>
```

The sequence similarly derives:

```text
adventure_sequence_<sequence_id>
```

Loading a scene restores completed chunks before graph availability is evaluated. This means completed branches remain resolved and their managed content is restored to its completed state.

## Debug contract

`AdventureSequenceDirector.get_graph_snapshot()` returns:

- sequence identity,
- started/completed state,
- active chunk IDs,
- available chunk IDs,
- completed chunk IDs,
- completion order,
- every chunk's dependencies,
- every requirement's status,
- content ownership,
- and validation errors.

This snapshot is intended for labs, automated tests, debug overlays, save inspection, and future production tooling.

## Regression scenes

Core graph behavior:

```text
res://scenes/tests/adventure_chunk_runtime_smoke_test.tscn
```

Production mini-dungeon integration:

```text
res://scenes/tests/adventure_chunk_mini_dungeon_smoke_test.tscn
```
