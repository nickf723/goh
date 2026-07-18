# Gremlin Action Selection v1 Test

## Goal

Verify that one enemy can perceive distance, choose between multiple reusable actions, commit through the existing action runner, and reconsider after the result.

The Gremlin now has:

- `Close Bite`
  - Start window: `0.0m - 1.15m`
  - Contact range: `1.1m`
  - Fast windup and recovery
  - Tight snap presentation
- `Pounce`
  - Start window: `1.65m - 3.1m`
  - Contact range: `0.9m`
  - Locked high-speed lunge
  - Long punishable recovery
- Reposition window
  - Between `1.15m` and `1.65m`
  - Circles toward its preferred spacing instead of forcing an invalid action

## Architecture added

- `EnemyActionOption`
  - Wraps an attack with its selection role, distance window, contact range, weight, stop-on-hit behavior, and presentation.
- `EnemyActionPresentation`
  - Gives each action its own windup, active, and recovery telegraph tuning.
- `EnemyActionSelectionBrain`
  - Filters valid actions by distance.
  - Scores valid actions by action weight, distance fit, and personality role preference.
  - Preserves zone hesitation and steering from PR #106.
  - Executes the selected action through PR #107's action runner.
  - Repositions during gaps and cooldowns.
  - Uses personality data for post-miss retreat behavior.

## Manual playtest

1. Pull `agent/gremlin-action-selection-v1`.
2. Open `scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn`.
3. Run Current Scene and enable developer/debug data.

### Close Bite

1. Stand within roughly one meter of a Gremlin.
2. Confirm debug `selected` becomes `Close Bite`.
3. Confirm the Gremlin uses the short snap telegraph rather than the crouched pounce tell.
4. Stay close and confirm exactly one hit.
5. Step outside contact range during the bite window and confirm it misses.

### Pounce

1. Stand between roughly 1.7 and 3.1 meters away.
2. Confirm debug `selected` becomes `Pounce`.
3. Confirm the Gremlin crouches, locks its direction, and launches.
4. Sidestep after commitment and confirm it overshoots along the original line.
5. Stay in line and confirm damage only occurs after the Gremlin physically reaches the close contact range.

### Reposition gap

1. Hold Grace around 1.3 to 1.5 meters away.
2. Confirm the Gremlin does not bite from too far away or begin a cramped pounce.
3. Confirm debug `selected` shows `reposition`.
4. Confirm it circles and drifts toward a valid action window.

### Cooldown and reconsideration

1. Let either action complete.
2. Confirm the Gremlin repositions during cooldown rather than immediately starting another attack.
3. Move from close range to mid-range during cooldown.
4. Confirm the next completed decision becomes Pounce.
5. Move from mid-range to close range and confirm the next completed decision becomes Close Bite.

### Skittish miss response

1. Dodge a pounce.
2. Wait through recovery.
3. Confirm debug `retreat` becomes positive.
4. Confirm the Gremlin briefly moves away from Grace before selecting another action.
5. Confirm hazard steering still affects this retreat direction.

### Personality hook

Temporarily change `personality_id` in the Gremlin brain:

- `bold`: stronger preference for lunge actions and faster commitment.
- `cautious`: weaker preference for lunges and a small retreat after misses.
- `skittish`: avoids close attacks when alternatives overlap and retreats longest after misses.
- `brute`: favors close melee pressure and does not retreat after misses.

The current bite and pounce windows barely overlap, so distance remains the primary choice. Personality weights become more visible as additional actions with overlapping windows are added.

## Debug fields

- `selected`
- `selection_score`
- `committed_option`
- `retreat`
- Existing pipeline fields: `action`, `phase`, `phase_time`, `interruptible`, and `hit`

## Known limitations

- Bite and pounce share one global attack cooldown.
- Selection is deterministic and currently chooses the highest score.
- Contact still uses the locked range-and-cone model rather than physics hitboxes.
- The Gremlin has no defensive action yet, so repositioning uses its existing circle behavior.

## Creative review

Judge whether the two tells are distinguishable without reading debug text, whether the gap between bite and pounce creates interesting footwork rather than indecision, and whether the skittish retreat makes the Gremlin feel alive without making it tedious to chase.
