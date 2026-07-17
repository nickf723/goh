# Progression Framework v1 Test

## Goal

Prepare the prototype for lots of mechanics without turning every reward into a one-off script.

This pass adds a central progression ledger:

```text
unlock id -> type -> menu-ready row -> save data -> query hooks
```

The goal is not to add a new combat toy yet. The goal is to make future toys safer to add.

## What changed

- Adds `scripts/systems/unlock_catalog.gd`.
- Updates `scripts/systems/game_state.gd` with progression unlock state.
- Updates the Church Trial reward altar to grant progression unlocks.

## Unlock types supported

```text
key_item
spell
modifier
passive
permission
```

## New GameState helpers

```gdscript
grant_unlock(unlock_id, unlock_data)
revoke_unlock(unlock_id)
has_unlock(unlock_id)
get_unlock_snapshot()
get_unlock_rows()
get_unlock_rows_by_type(type)
get_modifier_unlock_rows()
get_permission_unlock_rows()
get_active_modifier_ids()
get_unlock_type_counts()
```

## Current catalog entries

```text
church_trial_sigil       key_item
church_trial_doors       permission
armor_trial_blessing     modifier
firebolt                 spell definition placeholder
blink                    spell definition placeholder
charged_firebolt         future modifier placeholder
```

Only granted unlocks are active. The spell placeholders are definitions for future reward work, not automatic rewards.

## Test flow

1. Pull branch `agent/progression-framework-v1`.
2. Open Godot.
3. Open `scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn`.
4. Run Current Scene.
5. Press `F8` if you want a clean save.
6. Defeat the Animated Armor.
7. Claim the Church Trial Sigil.
8. Confirm the normal reward message appears.
9. Confirm there are no parser errors from `game_state.gd`, `unlock_catalog.gd`, or `church_trial_reward_altar.gd`.
10. Restart the scene.
11. Confirm Grace still has the sigil and can complete the final exit.

## Expected result

The visible gameplay should stay mostly the same:

```text
boss -> altar -> sigil -> save -> final exit
```

Under the hood, the altar now grants:

```text
church_trial_sigil       key item unlock
church_trial_doors       world permission unlock
armor_trial_blessing     modifier unlock placeholder
```

The save file now stores:

```text
key_items
unlocks
story_flags
stats
objective
bed position
```

## Why this matters

Future rewards can now be represented as data before they become full mechanics:

```text
Blink upgrade
Firebolt modifier
bed-rest blessing
world permission
new spell
passive rule change
combo expansion
```

This keeps Grace's growth feeling constant while keeping the codebase from becoming a cabinet of loose gears.

## Known limitations

- Unlocks are not rendered in a dedicated menu panel yet.
- Modifier hooks are cataloged but not applied to combat behavior yet.
- Spell definitions in the unlock catalog do not yet control the actual learned spell list.
- I could not run Godot here, so parser and scene validation are needed.
