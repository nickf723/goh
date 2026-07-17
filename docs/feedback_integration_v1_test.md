# Feedback Integration v1 Test

## Goal

Wire shared feedback presets into real prototype events instead of keeping them only in the F5 calibration tester.

```text
event happens -> GameFeedback.play(preset) -> controller response
```

## What changed

- `scripts/combat/payload_receiver.gd`
  - Charged or heavy-impact-tagged payloads now play `GameFeedback.play("heavy_impact")` when they reach a `HitReceiver`.
  - This gives Charged Firebolt a second impact rumble when the projectile actually lands.
- `scripts/levels/prototype_upgrade_lab.gd`
  - The lab tracks Guard stat drops.
  - When Guard decreases from a positive value, it plays `GameFeedback.play("guard_block")`.
  - F8 reset suppresses this guard feedback so reset does not feel like a shield block.
  - Existing F5 preset testing remains available.

## Fast test scene

Open:

```text
scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn
```

## Charged impact test

1. Run Current Scene.
2. Connect a controller.
3. Use the Charged Firebolt pedestal, or press `F6`.
4. Equip Firebolt.
5. Hold cast until full charge.
6. Confirm the existing full-charge meter/pulse/rumble still works.
7. Release Charged Firebolt into a passive target or goblin.
8. Confirm a heavier impact rumble fires when the charged projectile hits.

## Guard block feedback test

1. Press `F6` to grant core lab upgrades.
2. Use the save bed or Armor Trial Blessing station to get Guard if needed.
3. Let the live goblin hit Grace once.
4. Confirm Guard absorbs the hit.
5. Confirm the controller gives a compact guard-block rumble.
6. Press `F8` to reset.
7. Confirm reset gives the light tick, not the guard-block rumble.

## Regression checks

- Normal, uncharged Firebolt should not trigger `heavy_impact`.
- F5 should still cycle all feedback presets.
- F6 and F8 should still produce the light tick.
- The charge meter should still disappear after a charged shot releases.

## Known limitations

- Guard block feedback is currently connected in the upgrade lab director, not a global combat event bus.
- Charged Firebolt's full-charge pulse still lives in the UI path from the prior polish pass.
- This pass intentionally keeps the integration small so haptic feel can be tested before the feedback system grows into a full event bus.
- Parser and controller validation still need Godot testing.
