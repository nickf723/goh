# Tactical AI Laboratory and Decision Replay v1

## Purpose

The Tactical AI Laboratory turns the reaction-aware tactical and squad coordination systems into an inspectable development tool.

It provides:

- deterministic scenario recipes
- one-decision stepping
- a capped tactical flight recorder
- duplicate-frame collapsing
- backward and forward timeline navigation
- JSON replay export
- a telemetry-gated decision overlay
- live recorder adapters for enemy squad brains and Ruvia

The replay is tactical rather than physical. It records what an actor could observe, which candidates it evaluated, why it selected an action, and what squad reservations existed. It does not rewind physics, animation, health, or scene state.

## Laboratory scenarios

The launchable laboratory includes five recipes:

1. `Wet -> Lightning -> Conduct`
2. `Frozen + reserved Shatter -> reject Fire conversion`
3. `Cover request -> favor ranged response`
4. `Occupied melee lane -> redirect the next actor`
5. `Critical health -> emergency defense overrides combo value`

Each press of **Advance One Decision** runs the selected recipe through the real `ReactionTacticalPlanner` and records the resulting trace.

## Flight recorder contract

`TacticalDecisionRecorder` stores a capped array of serializable frames.

A frame contains:

- sequence number
- source ID and public source name
- decision event
- sanitized tactical decision trace
- sanitized squad coordination state
- scenario or runtime metadata
- repeat count
- stable fingerprint

Live `Node`, `Resource`, and other `Object` references are converted to descriptive dictionaries before storage. Known runtime-only fields such as `selected_candidate` and `source_ref` are omitted.

Identical adjacent decisions share one frame and increase `repeat_count`. This prevents an unchanged tactical choice from flooding the timeline.

## Overlay controls

- `F2`: show or hide the decision overlay
- `,` or Left: previous frame
- `.` or Right: next frame
- `Space` or Enter in the lab: advance one decision
- `R` in the lab: clear replay

The overlay disables its `_process` loop while hidden and updates visible text only when the recorder signature changes.

## Runtime integrations

### Enemy squad brains

`EnemySquadTacticalActionBrain` records:

- `decision` after action selection and reservation creation
- `coordination_release` after completion, interruption, cancellation, state finish, or removal

### Ruvia

`ReactionAwareRuviaControlDriver` records:

- evaluated reaction override decisions
- denied reservations
- granted reaction spell overrides
- coordination release after completion, failure, rebound, or removal

Neither integration records ordinary per-frame movement measurement.

## Export

The laboratory exports to:

```text
user://tactical_ai_reports/tactical_decision_replay.json
```

The export contains schema version, frame count, capacity, cursor position, duplicate count, and all sanitized frames.

## Automated test

```powershell
& "C:\Users\nickf\Downloads\Godot_v4.6.2-stable_win64.exe" --headless --path . res://scenes/tests/tactical_ai_lab_replay_smoke_test.tscn
```

Expected:

```text
TACTICAL_AI_LAB_REPLAY_SMOKE_TEST: PASS
```

The regression verifies recorder sanitization, deduplication, history limits, navigation, JSON export, the five scenario outcomes, overlay dormancy, and live enemy and companion recorder adapters.

## Known limitations

- The lab uses abstract candidates rather than spawned combat actors.
- Replay frames do not restore world state.
- The overlay binds to one recorder at a time.
- Runtime levels do not automatically install a global tactical overlay.
- Final visual styling and controller glyphs remain replacement-ready.
