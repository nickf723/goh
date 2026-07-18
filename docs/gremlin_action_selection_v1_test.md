# Gremlin Action Selection v1 Test

## Goal

Verify that one enemy can perceive distance, choose between multiple reusable actions, commit through the existing action runner, and reconsider after the result.

The Gremlin now has:

- `Close Bite`
  - Start window: `0.0m - 1.15m`
  - Contact range: `1.1m`
  - Fast windup and recovery
  - Tight snap presentation
  - Can interrupt a post-miss retreat when Grace corners the Gremlin
  - Independent `0.75s` reuse cooldown
- `Pounce`
  - Start window: `1.65m - 3.1m`
  - Contact range: `0.9m`
  - Locked high-speed lunge
  - Long punishable recovery
  - Independent `1.4s` reuse cooldown
- Reposition window
  - Between `1.15m` and `1.65m`
  - Circles toward its preferred spacing instead of forcing an invalid action

## Architecture added

- `EnemyActionOption`
  - Wraps an attack with its selection role, distance window, contact range, weight, stop-on-hit behavior, presentation, reuse cooldown, and retreat-interrupt rule.
- `EnemyActionPresentation`
  - Gives each action its own windup, active, and recovery telegraph tuning.
- `EnemyActionSelectionBrain`
  - Filters valid actions by distance and per-action cooldown.
  - Scores valid actions by action weight, distance fit, and personality role preference.
  - Preserves zone hesitation and steering from PR #106.
  - Executes the selected action through PR #107's action runner.
  - Repositions during gaps and the very short shared decision pause.
  - Uses personality data for post-miss retreat behavior.
  - Allows designated close responses to interrupt retreat when cornered.

## Manual playtest

1. Pull `agent/gremlin-action-selection-v1`.
2. Open `scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn`.
3. Run Current Scene and enable developer/debug data.
4. A Gremlin should already be placed with the training targets.

### Close Bite

1. Stand within roughly one meter of the Gremlin.
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

### Pounce into Bite

1. Let a pounce connect.
2. Remain within close range after the pounce recovery.
3. Confirm the Pounce option enters its own cooldown while Close Bite remains available.
4. Confirm the next action is Close Bite rather than another pounce.
5. Confirm debug `option_cooldowns` shows Pounce cooling independently.

### Cornered after a miss

1. Dodge a pounce.
2. Wait through its recovery, then immediately chase the Gremlin.
3. Enter Close Bite range before its skittish retreat finishes.
4. Confirm the retreat is cancelled and Close Bite begins.
5. Repeat without chasing and confirm the Gremlin completes its retreat normally.

### Reposition gap

1. Hold Grace around 1.3 to 1.5 meters away.
2. Confirm the Gremlin does not bite from too far away or begin a cramped pounce.
3. Confirm debug `selected` shows `reposition` or a cooling-action summary.
4. Confirm it circles and drifts toward a valid available action window.

### Independent cooldowns

1. Let Close Bite complete.
2. Confirm Bite enters cooldown without blocking Pounce at mid-range.
3. Move into pounce range and confirm Pounce can be selected while Bite is cooling.
4. Let Pounce complete and confirm the reverse behavior at close range.
5. Confirm no single move can monopolize all future decisions.

### Personality hook

Temporarily change `personality_id` in the Gremlin brain:

- `bold`: stronger preference for lunge actions and faster commitment.
- `cautious`: weaker preference for lunges and a small retreat after misses.
- `skittish`: prefers darting attacks, retreats longest after misses, and bites when cornered.
- `brute`: favors close melee pressure and does not retreat after misses.

The current bite and pounce windows barely overlap, so distance remains the primary choice. Personality weights become more visible as additional actions with overlapping windows are added.

## Debug fields

- `selected`
- `selection_score`
- `committed_option`
- `retreat`
- `option_cooldowns`
- Existing pipeline fields: `action`, `phase`, `phase_time`, `interruptible`, and `hit`

## Known limitations

- Selection is deterministic and currently chooses the highest valid score.
- Contact still uses the locked range-and-cone model rather than physics hitboxes.
- The Gremlin has no defensive action yet, so repositioning uses its existing circle behavior.

## Creative review

Judge whether the two tells are distinguishable without reading debug text, whether Pounce naturally hands combat to Bite when it lands, whether chasing a missed pounce creates a satisfying cornered response, and whether the independent cooldowns produce a lively rhythm instead of mechanical alternation.
