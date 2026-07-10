# Enemy Overhead HUD Test

## Goal

Make enemy state readable while fighting, not only when a popup first appears.

This pass adds persistent overhead bars and active status icons to enemies.

## Branch

`agent/enemy-bars-status-icons-v1`

## What changed

- Enemies now get a runtime `EnemyOverheadHud` node.
- The HUD floats above the enemy.
- Bar quads and icon labels use built-in billboarding so they face the camera without mirrored letters.
- Bar materials render double-sided so the health and stance bars remain visible from the player camera.
- It shows:
  - A health bar.
  - A smaller stance bar.
  - Small active-status icons below the bars.
- Status icons update while effects are active and disappear when effects expire.
- Oily can be detected from active statuses or `TagComponent` tags.

## Status icon legend

- `F` = burning.
- `P` = poisoned.
- `*` = frozen.
- `C` = chill.
- `Z` = stunned.
- `W` = wet.
- `!` = staggered.
- `O` = oily.

## How to test

1. Pull branch `agent/enemy-bars-status-icons-v1`.
2. Run the usual dev scene.
3. Use `F9` / `F10` to select one of these scenarios:
   - `Goblin Duel`
   - `Gremlin Duel`
   - `Zombie Duel`
   - `Mixed Wave`
   - `Hazard Combo Lab`
4. Press `F6` to spawn enemies.
5. Confirm each enemy has a small overhead HUD.
6. Confirm the health and stance bars are visible before and after combat starts.
7. Lock on with `R3` / `T` and cast spells.
8. Confirm the health and stance bars update after hits.
9. Apply statuses:
   - Poison Cloud should show `P`.
   - Fire Field should show `F`.
   - Oil should show `O` before it ignites.
   - Ice Lance / chill effects should show `C` or `*` where applicable.
   - Lightning effects should show `Z` when stunned.
10. Wait for statuses to expire and confirm icons vanish.
11. Confirm the `F` icon reads normally and is not mirrored.

## Expected behavior

- Health bar shrinks when health damage lands.
- Stance bar shrinks when stance damage lands.
- Active status icons persist while the status is active.
- Icons disappear after the effect expires or is removed by a conflict.
- Oily appears while the target has an oily status or oily tag, not only after burning starts.
- Existing floating combat text still appears normally.

## Tuning knobs

In `scripts/combat/enemy_overhead_hud.gd`:

- `vertical_padding`
- `bar_width`
- `health_bar_height`
- `stance_bar_height`
- `icon_spacing`
- `icon_y_offset`

## Known risks

- This is still a runtime prototype HUD. Later we can replace the letter icons with small textured symbols.
- Bar placement is estimated from collision shape height, so some custom enemies may need a small offset later.
