# Game Feedback v1 Test

## Goal

Create a reusable haptic feedback vocabulary so future mechanics can share the same controller feel instead of each feature hardcoding its own rumble.

```text
mechanic event -> GameFeedback.play("preset_id") -> controller haptic response
```

## What changed

- `scripts/systems/game_feedback.gd`
  - Adds shared feedback presets.
  - Supports haptic playback through `Input.start_joy_vibration`.
  - Supports device `0` by default and device `-1` for all connected joypads.
  - Returns feedback metadata so callers can display readable labels.
- `scripts/levels/prototype_upgrade_lab.gd`
  - Adds an editor-only feedback test shortcut.
  - `F5` cycles through configured feedback presets.
  - `F6` and `F8` now use a light tick feedback when granting or resetting lab state.

## Current presets

```text
light_tick
full_charge
guard_block
heavy_impact
low_health_warning
```

## Scene

Open:

```text
scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn
```

Run Current Scene.

## Feedback shortcut test

1. Connect a controller.
2. Press `F5`.
3. Confirm a haptic preset plays and the message shows its name.
4. Press `F5` repeatedly.
5. Confirm the presets cycle in this order:

```text
light_tick -> full_charge -> guard_block -> heavy_impact -> low_health_warning
```

6. Notice the difference between:
   - `light_tick`: tiny UI confirmation.
   - `full_charge`: rising spell-ready punch.
   - `guard_block`: shield-like thunk.
   - `heavy_impact`: big hit rumble.
   - `low_health_warning`: warning pulse.

## Lab shortcut regression

1. Press `F6`.
2. Confirm core lab upgrades are granted.
3. Confirm a small `light_tick` haptic plays.
4. Press `F8`.
5. Confirm lab progression resets.
6. Confirm a small `light_tick` haptic plays.

## Charged Firebolt regression

1. Use the Charged Firebolt pedestal or press `F6`.
2. Equip Firebolt.
3. Hold cast until full charge.
4. Confirm the existing charge meter and full-charge rumble still work.
5. Release to fire.
6. Confirm no charge meter lingers.

## Notes

- This is a first shared feedback utility, not a full event bus yet.
- Charged Firebolt's full-charge UI still owns its existing pulse and rumble path.
- The new `GameFeedback` script gives future systems a common preset vocabulary first.
- Guard block and impact events can be wired into combat next.
- I could not run Godot here, so parser and controller validation are needed.
