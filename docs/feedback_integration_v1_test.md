# Feedback Integration v1 Test

## Goal

Wire shared feedback presets into real prototype events instead of keeping them only in the F5 calibration tester.

```text
event happens -> GameFeedback.play(preset) -> controller response
```

## What changed

- `scripts/systems/game_feedback.gd`
  - Adds `hit_collision` for light contact feedback.
  - Adds `player_hit` for Grace taking unguarded damage.
- `scripts/combat/payload_receiver.gd`
  - Any payload that reaches a `HitReceiver` now plays haptic feedback.
  - Charged or heavy-impact-tagged payloads play `GameFeedback.play("heavy_impact")`.
  - Normal payloads play `GameFeedback.play("hit_collision")`.
- `scripts/levels/prototype_upgrade_lab.gd`
  - The lab still tracks Guard stat drops and plays `GameFeedback.play("guard_block")`.
  - The lab now tracks Health stat drops and plays `GameFeedback.play("player_hit")` for unguarded damage.
  - F8 reset suppresses hit feedback so reset does not feel like a shield block or damage hit.
  - F5 preset testing now includes `hit_collision` and `player_hit`.

## Fast test scene

Open:

```text
scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn
```

## F5 preset tester

1. Run Current Scene.
2. Connect a controller.
3. Press `F5` repeatedly.
4. Confirm the lab cycles through:
   - `light_tick`
   - `hit_collision`
   - `player_hit`
   - `full_charge`
   - `guard_block`
   - `heavy_impact`
   - `low_health_warning`

## Charged impact test

1. Run Current Scene.
2. Connect a controller.
3. Use the Charged Firebolt pedestal, or press `F6`.
4. Equip Firebolt.
5. Hold cast until full charge.
6. Confirm the existing full-charge meter/pulse/rumble still works.
7. Release Charged Firebolt into a passive target or goblin.
8. Confirm a heavier impact rumble fires when the charged projectile hits.

## Normal hit-collision test

1. Equip normal, uncharged Firebolt.
2. Tap cast into a passive target.
3. Confirm a lighter contact rumble fires on hit.
4. Confirm it feels smaller than Charged Firebolt's `heavy_impact`.

## Guard block feedback test

1. Press `F6` to grant core lab upgrades.
2. Use the save bed or Armor Trial Blessing station to get Guard if needed.
3. Let the live goblin hit Grace once.
4. Confirm Guard absorbs the hit.
5. Confirm the controller gives a compact guard-block rumble.

## Unguarded player-hit test

1. After Guard is spent, let the live goblin hit Grace again.
2. Confirm Grace takes health damage.
3. Confirm the controller gives a `player_hit` rumble.
4. Confirm this feels different from the guarded shield-thunk.

## Reset regression

1. Press `F8` to reset.
2. Confirm reset gives the light tick.
3. Confirm reset does not play `guard_block` or `player_hit`.

## Regression checks

- Normal, uncharged Firebolt should trigger `hit_collision`, not `heavy_impact`.
- Charged Firebolt should still trigger `heavy_impact` on impact.
- F5 should still cycle all feedback presets.
- F6 and F8 should still produce the light tick.
- The charge meter should still disappear after a charged shot releases.

## Known limitations

- Guard block and unguarded player-hit feedback are currently connected in the upgrade lab director, not a global combat event bus.
- Target hit-collision feedback is wired through `PayloadReceiver`, so it should apply anywhere a payload reaches a `HitReceiver`.
- Charged Firebolt's full-charge pulse still lives in the UI path from the prior polish pass.
- This pass intentionally keeps the integration small so haptic feel can be tested before the feedback system grows into a full event bus.
- Parser and controller validation still need Godot testing.