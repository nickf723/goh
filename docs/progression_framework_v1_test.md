# Progression Framework v1 Test

## Goal

Prepare Grace's growth curve for many future mechanics without turning every reward into a one-off script.

The new progression pattern is:

```text
unlock id -> type -> catalog row -> save data -> query helpers -> gameplay payoff
```

This pass also proves the first modifier-style payoff:

```text
Armor Trial Blessing -> sleep at bed -> gain Guard -> next hit is absorbed
```

## Scene

Open:

```text
scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn
```

Run Current Scene.

## What changed

- `scripts/systems/unlock_catalog.gd`
  - Adds catalog definitions for progression unlocks.
  - Supports unlock types:
    - `key_item`
    - `spell`
    - `modifier`
    - `passive`
    - `permission`
  - Adds initial entries:
    - `church_trial_sigil`
    - `church_trial_doors`
    - `armor_trial_blessing`
    - `firebolt`
    - `blink`
    - `charged_firebolt`
- `scripts/systems/game_state.gd`
  - Adds `unlocks` state.
  - Adds `grant_unlock()`.
  - Adds `revoke_unlock()`.
  - Adds `has_unlock()`.
  - Adds unlock row helpers for menu/debug display.
  - Saves and loads unlocks.
  - Keeps old key-item saves compatible with the new unlock ledger.
  - Adds prototype Guard support.
- `scripts/interaction/church_trial_reward_altar.gd`
  - Grants progression unlocks when Grace claims the sigil:
    - `church_trial_sigil`
    - `church_trial_doors`
    - `armor_trial_blessing`
- `scripts/interaction/save_bed.gd`
  - Applies rest unlocks after sleeping.
  - Grants 1 Guard when Grace has Armor Trial Blessing.
- `scripts/levels/prototype_boss_dungeon_chain.gd`
  - Spawns a Guard Test Goblin after Grace has Armor Trial Blessing and at least 1 Guard.

## Main flow

1. Press `F8` to clear the prototype save if needed.
2. Defeat the Animated Armor.
3. Claim the Church Trial Sigil.
4. Confirm the reward text still appears.
5. Confirm the final exit still works.
6. Restart the scene.
7. Confirm saved progression still resumes correctly.

## Guard payoff flow

1. Claim the sigil and gain Armor Trial Blessing.
2. Sleep at a save bed.
3. Confirm the message says:

```text
Armor Trial Blessing grants 1 Guard.
```

4. Confirm a Guard Test Goblin appears nearby.
5. Let it hit Grace once.
6. Confirm Guard absorbs the hit.
7. Let it hit again.
8. Confirm normal health damage happens once Guard is gone.

## Save compatibility checks

- Old save with `claimed_church_trial_sigil = true` should still count as having the sigil.
- Old key-item save should create compatible unlock rows.
- New unlock save should preserve:
  - key item unlocks
  - permission unlocks
  - modifier unlocks
  - current Guard value

## Known limitations

- Unlocks are menu-ready but not rendered in a dedicated menu panel yet.
- Guard is currently a prototype dynamic stat, not a polished HUD resource.
- The Guard Test Goblin is for prototype verification only.
- Spell catalog entries do not yet drive the actual learned spell list.
- Modifier hooks are still direct checks, not a full declarative modifier engine yet.
- I could not run Godot here, so parser and scene validation are needed.
