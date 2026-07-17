# Charged Firebolt Feel v1 Test

## Goal

Give Charged Firebolt a clearer prototype feel loop:

```text
hold cast -> visible charge meter -> full-charge pulse -> controller rumble -> release charged projectile
```

This is the first pass at making active spell upgrades feel game-native instead of only changing numbers behind the curtain.

## Branch

```text
agent/charged-firebolt-feel-v1
```

This PR is stacked on `agent/prototype-upgrade-lab-v1`, which is stacked on `agent/charged-firebolt-v1`.

## Scene

Open:

```text
scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn
```

Run Current Scene.

## What changed

- `scripts/ui/game_ui.gd`
  - Adds a dynamic Charged Firebolt meter.
  - Parses the existing `Charging Firebolt: X%` spell label from `AbilityCaster`.
  - Shows a bottom-center charge panel while charging.
  - Swaps to a `FULL CHARGE` state at 100%.
  - Pulses the panel when full charge is reached.
  - Starts controller vibration on device 0 at full charge.
  - Hides the meter when the spell label returns to a normal spell name.

## Fast test flow

1. Open the upgrade lab scene.
2. Use the Charged Firebolt pedestal, or press `F6` to grant core lab upgrades.
3. Equip Firebolt.
4. Tap cast.
5. Confirm normal Firebolt casts and the charge meter does not linger.
6. Hold cast.
7. Confirm the charge meter appears near the lower center of the screen.
8. Hold until it reaches full charge.
9. Confirm the panel changes to `FULL CHARGE`.
10. Confirm the panel pulses.
11. On controller, confirm a short rumble happens at full charge.
12. Release cast.
13. Confirm Charged Firebolt fires and the meter disappears.

## Regression checks

- Opening the focus spell menu should still hide the normal spell list.
- Focus menu quick-cast should still cast normally and should not show the charge meter.
- Switching spells while charging should hide the meter after the equipped spell label updates.
- Player defeat should hide the charge meter.
- The meter should not appear for other spells.

## Known limitations

- The charge meter is still prototype UI, not final art.
- Controller vibration targets device 0 for now.
- Cancel rules are still mostly handled by the existing `AbilityCaster` state reset paths.
- No sound effect yet.
- I could not run Godot here, so parser and controller validation are needed.
