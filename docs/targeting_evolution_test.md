# Targeting Evolution v1 Test Notes

## Goal

Make lock-on feel more useful while casting from the focus selector.

## What changed

- Locked spells now ask the player for a lock-on cast direction.
- If Grace is locked onto a target, casts aim at that target's aim point instead of blindly using camera-forward.
- Right-stick left/right flicks switch targets while locked on.
- Keyboard fallbacks:
  - `T`: toggle lock-on.
  - `,`: previous target.
  - `.`: next target.
- R3 still toggles lock-on.
- The lock marker now pulses so it is easier to read during combat.
- Lock-on toggle and target cycling are handled before the focus selector eats input, so targeting can be adjusted while focus is open.

## Controller test

1. Pull branch `agent/targeting-evolution-v1`.
2. Run the usual dev scene.
3. Pick `Hazard Combo Lab`, `Mixed Wave`, or `Zombie Pair` with `F9` / `F10`.
4. Press `F6` to spawn enemies.
5. Press `R3` to lock onto an enemy.
6. Hold `ZL` to open the focus selector.
7. Cast Firebolt, Wind Gust, Poison Cloud, or Fire Field with `ZR`.
8. Confirm casts aim toward the locked enemy.
9. While still locked, flick right stick left/right to switch targets.
10. Confirm the marker moves to the new target.

## Keyboard fallback test

1. Press `T` to lock on.
2. Press `,` and `.` to switch targets.
3. Cast with `Q`.

## Expected behavior

- Locked target marker pulses above the enemy.
- Spells cast toward the locked target.
- Target switching works with the right stick while locked.
- Focus selector remains usable with D-pad.
- Lock-on clears when the enemy dies or gets too far away.

## Tuning knobs

In `scripts/player/player_controller.gd`:

- `lock_on_switch_deadzone`
- `lock_on_switch_cooldown`
- `lock_on_aim_height`
- `lock_on_marker_pulse_speed`
- `lock_on_marker_pulse_size`

## Known risks

- The exact aim point is currently a simple height offset from the enemy root.
- Target switching uses right-stick flicks. If it switches too eagerly, increase `lock_on_switch_deadzone` or `lock_on_switch_cooldown`.
- Some actions that flatten their direction, such as ground hazards, will still ignore vertical aim by design.
