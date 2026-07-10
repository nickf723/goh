# Enemy Pressure Test

## Goal

Make enemy attacks easier to trigger and easier to understand in the prototype.

Before this pass, enemies could stop just outside their true attack range because their preferred spacing band was wider than the attack hit range. That made them feel like they were waiting for an invisible opening.

This pass makes enemies pressure proactively:

- If cooldown is ready and Grace is close, the enemy closes into real attack range.
- Once actually in attack range, the enemy briefly commits, faces Grace, then starts its normal windup.
- If cooldown is not ready and the enemy is already in attack range, it can circle/wait as before.
- The enemy no longer treats the outer preferred-spacing band as a reason to stop before it can hit.

## Branch

`agent/enemy-pressure-v1`

## What changed

- `scripts/enemies/enemy_brain.gd`
  - Adds `attack_commit_time`.
  - Adds `attack_pressure_range_padding`.
  - Adds `attack_commit_timer` debug state.
  - Changes chase logic so enemies only wait/circle when they are actually inside attack range and waiting for cooldown.
  - Keeps moving forward when they are in the spacing band but still outside attack range.
  - Adds a short proactive pressure commit before windup.

## How to test

1. Pull branch `agent/enemy-pressure-v1`.
2. Run the usual dev scene.
3. Spawn `Goblin Duel`.
4. Stand near the Goblin without attacking.
5. Confirm the Goblin closes and attacks on its own instead of hovering forever.
6. Spawn `Gremlin Duel`.
7. Confirm the Gremlin can still circle, but should bite proactively when it gets close enough.
8. Spawn `Zombie Duel`.
9. Confirm the Zombie still feels slower and more readable, but eventually commits to its grab.
10. Use Dev Vision and watch:
    - `last: closing: ...`
    - `last: pressuring: ...`
    - `last: windup: ...`
    - `commit: ...`

## Expected behavior

- Enemies should not require Grace to whiff attacks before they attack.
- Enemies should not hover just outside range forever.
- Cooldown circling still works after an attack.
- Windup telegraph still reads as the main warning.
- Gobby may kill Grace more honestly now.

## Tuning knobs

In `EnemyBrain`:

- `attack_commit_time`
  - Higher means enemies pause/face Grace longer before windup.
  - Lower means enemies attack more aggressively.

- `attack_pressure_range_padding`
  - Higher means enemies start closing/committing from slightly farther away.
  - Lower means they must be closer before pressure logic starts.
