# Prototype Upgrade Lab v1 Test

## Goal

Create a fast testing scene for progression upgrades so new mechanics do not require replaying an entire dungeon.

```text
open lab -> grant upgrade -> test on targets -> inspect menu -> reset -> repeat
```

This is the mechanic garage for future spell upgrades, blessings, permissions, and controller workflows.

## Scene

Open:

```text
scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn
```

Run Current Scene.

## What changed

- `scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn`
  - Adds a clean test room with player, UI, save bed, targets, pedestals, and controller signage.
  - Includes three passive Goblin Reaction Targets.
  - Includes one live Guard Test Goblin.
- `scripts/levels/prototype_upgrade_lab.gd`
  - Shows lab objective and opening message.
  - Adds editor shortcuts:
    - `F6`: grant core lab upgrades.
    - `F8`: reset lab progression.
  - Resets lab targets when requested.
- `scripts/interaction/upgrade_pedestal.gd`
  - Generic pedestal that can grant unlocks, reset progress, restore resources, show unlocks, or reset targets.
- `scenes/actors/interactables/upgrade_pedestal.tscn`
  - Reusable prototype pedestal visual and interaction area.

## Lab stations

- Charged Firebolt pedestal
  - Grants `charged_firebolt`.
  - Restores resources.
- Armor Trial Blessing pedestal
  - Grants `armor_trial_blessing`.
  - Restores resources and can grant Guard.
- Church Trial Kit pedestal
  - Grants `church_trial_sigil` and `church_trial_doors`.
- Resource Console
  - Restores health, mana, stamina, and stance.
- Unlock Inspector
  - Prints active unlocks.
- Target Reset
  - Resets lab targets.
- Progress Reset
  - Clears unlocks, Guard, story flags, and target state.

## Main test flow

1. Pull branch `agent/prototype-upgrade-lab-v1`.
2. Open the upgrade lab scene.
3. Run Current Scene.
4. Confirm the opening message appears.
5. Use the Charged Firebolt pedestal.
6. Equip Firebolt.
7. Tap cast and confirm normal Firebolt.
8. Hold cast and confirm charge text appears.
9. Release and confirm Charged Firebolt fires.
10. Repeat with controller right trigger.
11. Open the menu and confirm Charged Firebolt appears under Relics.
12. Use Target Reset and confirm the passive targets reset.
13. Use Progress Reset and confirm Charged Firebolt is removed.

## Controller test

The lab has signage for the current expected flow:

```text
Right Trigger: cast / hold to charge
R3 / T: lock-on
Tab / M / controller menu: full menu
```

Controller pass should confirm:

- Right trigger quick press casts normally.
- Right trigger hold charges Firebolt.
- Right trigger release fires charged Firebolt.
- Menu remains navigable after testing.

## Regression checks

- Existing boss dungeon still works.
- Existing Charged Firebolt reward flow still works.
- Save bed still saves/restores.
- Armor Trial Blessing still grants Guard on rest.
- Full menu still opens and shows Relics.

## Known limitations

- The lab is prototype art only.
- Pedestals use text prompts and simple geometry.
- The Church Trial Kit pedestal grants a key-item unlock, but does not currently call `add_key_item()` with custom key-item metadata.
- The live goblin is intentionally simple and may need better containment later.
- I could not run Godot here, so parser and scene validation are needed.
