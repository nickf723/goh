# Enemy Defensive Actions v1 Test

## Goal

Verify that enemies can choose a non-damaging defensive response through the same reusable combat-action architecture used by Bite and Pounce.

The shared loop is now:

`perceive -> choose offense or defense -> telegraph -> commit -> resolve -> recover -> reconsider`

## Architecture

### EnemyCombatActionDefinition

Shared contract for attacks, defenses, movement actions, support actions, and future utility actions.

It owns:

- Identity and action kind.
- Role tags.
- Windup, active, recovery, and cooldown timing.
- Movement mode.
- Per-phase movement multipliers.
- Facing behavior.
- Per-phase interruption rules.

### EnemyAttackDefinition

Now extends `EnemyCombatActionDefinition` while preserving attack classes, range/cone contact, payload generation, and miss behavior.

### EnemyDefenseDefinition

Extends the same base action contract and adds a defensive style plus defensive tags. The first style is `evade`.

### EnemyActionRunner

Now stores a generic combat action plus two separately locked directions:

- Target direction for facing and attack checks.
- Movement direction for lunges, retreats, strafes, and future movement actions.

### EnemyActionOption

Can wrap either a generic `action` or the legacy `attack` field. Existing Bite and Pounce resources remain compatible while new defenses use the generic field.

## First defensive action: Gremlin Backstep

- Kind: `defense`
- Style: `evade`
- Start window: `0.0m - 1.45m`
- Windup: `0.10s`
- Active movement: `0.22s` at `2.35x` speed
- Recovery: `0.28s`
- Reuse cooldown: `1.15s`
- Movement: locked away from Grace
- Facing: remains turned toward Grace
- Invulnerability: none

Backstep wins only when a stronger close-range action is unavailable. This produces the intended pressure chain:

`Pounce -> Close Bite -> Backstep`

## Manual playtest

1. Pull `agent/enemy-defensive-actions-v1`.
2. Open `scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn`.
3. Run Current Scene and enable the debug overlay.
4. Approach the Gremlin from pounce range.
5. Let Pounce connect and remain close.
6. Confirm the next close action is `Close Bite`, not Backstep.
7. Continue pressuring while Bite enters its independent cooldown.
8. Confirm `selected` changes to `Backstep`.
9. Confirm `selected_kind` and `action_kind` report `defense` during the defensive action.
10. Confirm the Gremlin gives a short blue tell, keeps facing Grace, and jumps backward along a committed line.
11. Confirm Backstep deals no damage.
12. Confirm it completes recovery before choosing another action.
13. Chase immediately and confirm the Gremlin can choose Bite or another available response after recovery.
14. Place a control hazard nearby and confirm existing hazard awareness still affects ordinary chasing and repositioning before commitment.

## Readability checks

- Bite should remain a fast pink/yellow snap.
- Pounce should remain a deep crouch followed by a forward launch.
- Backstep should use a cool blue compression followed by a backward snap.
- Backstep should create enough space to change the next decision without ejecting the Gremlin from combat.

## Automated contract

The architecture smoke test verifies:

- Close Bite wins at close range while available.
- Pounce wins at mid-range.
- Pounce cooldown does not block Bite.
- Bite cooldown opens Backstep at close range.
- Backstep resolves as `EnemyDefenseDefinition`, not an attack.
- Backstep uses `away_from_target` movement.
- Backstep active movement is faster than ordinary movement.

## Extension points

The same architecture can support:

- Side dodge using `strafe_left` or `strafe_right`.
- Shield guard with a stationary movement mode and receiver modifier hooks.
- Brace actions resistant to force or stance damage.
- Counters that wait defensively and emit an attack reaction.
- Boss evasions with unique telegraphs and recovery windows.

## Known limitations

- Backstep has no invulnerability frames; it defends by physically leaving the threatened space.
- Defensive movement currently locks at commitment and does not re-path during the active phase.
- Backstep can still collide with walls and may need collision-aware fallback behavior later.
- Guard, brace, and counter effects need receiver-side modifier hooks in later versions.
