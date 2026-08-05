# Runtime Performance Foundation v1

Grace of Humanity now treats performance as a gameplay contract rather than a late cleanup pass.

## Target budget

The initial target is 60 FPS:

- target frame time: 16.67 ms
- green p95: at or below 19.17 ms
- amber p95: at or below 26.67 ms
- red p95: above 26.67 ms
- default spike threshold: 25 ms

The target can be changed per `RuntimePerformanceMonitor` instance for lower-spec testing.

## Live overlay

Press **F7** in any scene using the shared `GameUI`.

The overlay reports:

- current FPS
- average, p95, and p99 frame time
- approximate one-percent-low FPS
- process and physics time
- draw calls and rendered objects
- node and active-processing counts
- visible Label3D count
- recent frame spikes

The overlay is hidden by default. Sampling remains active while hidden, but the more expensive scene-tree count is collected only while the overlay is visible.

## Unified HUD budget

`UnifiedHUDSourceBridgeBudgeted` replaces frame-by-frame polling:

- responsive geometry updates only when the viewport or HUD becomes dirty
- progression mirroring runs every 0.2 seconds
- duplicate legacy-surface suppression runs every 0.8 seconds
- node-added and viewport-size signals request immediate work when needed

`GameUIUnified` now polls only during startup while waiting for the player-owned HUD. Once found, objective and prompt updates are event driven.

## Mechanism lab budget

`MechanismNetworkLabPerformance` replaces the lab's ten-Hz global Label3D rewrite:

- logic labels update when their signal changes
- countdown labels update every 0.25 seconds only while a timer is active
- the lab disables `_process()` entirely when no timer is running
- unchanged label text and colors are cached and skipped
- instructional labels use renderer visibility ranges

Mechanism hardware also avoids unnecessary presentation churn:

- indicators cache their active and inactive materials
- element sensors cache materials and normalized element lists
- sliding gates use coarse OPENING/CLOSING/OPEN/CLOSED labels
- gate fraction signals are emitted at meaningful steps rather than every tween frame

## Authoring rules

1. Prefer signals over polling.
2. Disable `_process()` whenever a subsystem is idle.
3. Never rebuild Label3D text every frame.
4. Cache materials instead of allocating them for repeated state changes.
5. Give distant instructional geometry a visibility range.
6. Throttle debug and presentation work separately from gameplay simulation.
7. Use the F7 overlay before and after adding a substantial mechanic.
8. Add a deterministic regression for every new scheduler, cache, or culling rule.

## Regression

Run:

```text
res://scenes/tests/runtime_performance_foundation_smoke_test.tscn
```

The regression verifies frame-budget classification, overlay installation, budgeted HUD synchronization, material and label caching, gate signal throttling, Label3D visibility ranges, and the mechanism lab's sleep/wake lifecycle.
