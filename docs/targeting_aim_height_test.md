# Targeting Aim Height Test

## Goal

Fix lock-on projectile aiming for short enemies like Goblins and Gremlins.

Before this pass, lock-on aimed at a fixed height above the enemy root. That made straight projectiles travel over small enemies when targeting was enabled.

## What changed

- Lock-on aim now targets center mass instead of a fixed head-height point.
- The aim height is estimated from the target collision shape when possible.
- The aim point clamps to a practical range so tiny or tall targets do not produce extreme shots.
- The cast-origin fallback uses a separate player-side height so target height and Grace's casting height can be tuned independently.

## Tuning exports

On `PlayerController`:

- `lock_on_default_aim_height`: fallback target height when no collision shape is found.
- `lock_on_aim_height_ratio`: percentage of target body height to aim at.
- `lock_on_min_aim_height`: lowest allowed lock-on aim height.
- `lock_on_max_aim_height`: highest allowed lock-on aim height.
- `lock_on_cast_origin_height`: fallback height for Grace's cast origin when no explicit cast origin is supplied.

## How to test

1. Pull branch `agent/targeting-aim-height-v1`.
2. Run the usual dev scene.
3. Use `F9` / `F10` to select `Goblin Duel`, `Gremlin Duel`, or `Mixed Wave`.
4. Press `F6` to spawn enemies.
5. Press `R3` or `T` to lock on.
6. Cast a straight projectile spell like Firebolt or Ice Lance.
7. Confirm projectiles travel through the enemy body instead of flying over the enemy.
8. Try both Goblin and Gremlin.
9. Try Zombie too and confirm the aim still looks reasonable on taller enemies.

## Expected behavior

- Locked projectiles should hit small enemies more reliably.
- Projectiles should no longer aim at the top of Goblins or Gremlins.
- Target switching and the focus selector should still work.
- Ground hazards should still place on the floor in the selected/locked direction.

## Tuning note

If projectiles still skim high, lower `lock_on_aim_height_ratio` or `lock_on_max_aim_height` slightly. If they hit too low, raise `lock_on_min_aim_height` or `lock_on_aim_height_ratio`.