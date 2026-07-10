# Base Stats Structure Test

## Goal

Add Grace's 16 base stats as a visible structure before adding formulas, leveling, equipment scaling, or balance math.

This pass is meant to answer:

```text
Can the game clearly show what Grace's stats are for?
Can future spells/weapons/augments reference stable stat ids?
Can the full menu act as a stat design cockpit?
```

## 16 base stats

| Stat | Intended use |
|---|---|
| Health | Taking hits and staying alive |
| Stamina | Physical action fuel |
| Mana | Magical action fuel |
| Stance | Poise/stability under pressure |
| Power | Physical damage and heavy impact |
| Dexterity | Physical attack support, swing speed, start/end lag |
| Arcana | Magical damage and magical output |
| Intelligence | Spell handling, cast support, complex magic |
| Defense | Lower physical damage |
| Resilience | Lower magical damage |
| Constitution | Regenerate health, stamina, mana, and stance |
| Evasion | Avoid attacks and support dodging |
| Focus | Navigate menus while the world keeps moving |
| Charisma | NPC conversations and social checks |
| Skill | Provisional flexible technique/proc stat |
| Luck | Provisional chance/proc stat, name may change later |

## Files changed

- `scripts/systems/stat_catalog.gd`
  - New central stat definition catalog.
  - Owns default stat values, stat groups, stat descriptions, and elemental affinity sections.
- `scripts/systems/game_state.gd`
  - Uses `StatCatalog` for default stats.
  - Adds helpers for stat menu sections.
  - Fixes reset behavior so current/max resource values reset cleanly.
- `scripts/ui/full_menu_director.gd`
  - Sends stat sections into the full menu data.
- `scripts/ui/full_menu_shell.gd`
  - Adds a Stats tab.
  - Shows base stats and elemental affinity hooks.
  - Updates tab hotkeys from 1-4 to 1-5.

## What this does not do yet

- No damage formulas.
- No stat scaling on spells.
- No leveling.
- No XP.
- No equipment stat bonuses.
- No proc formulas.
- No stat editing UI.

## Notes on current values

Most long-term stats are still `1`.

Action resources currently stay prototype-friendly:

```text
health  = 5 / 5
stamina = 5 / 5
mana    = 5 / 5
stance  = 5 / 5
focus   = 5
```

This keeps the current spell/combat testing loop usable while the structure forms. Later we can decide whether Health, Stamina, Mana, Stance, and Focus are direct stats, derived max values, or both.

## How to test

1. Pull branch:

```text
agent/base-stats-structure-v1
```

2. Open Godot.
3. Confirm no parser errors from:
   - `stat_catalog.gd`
   - `game_state.gd`
   - `full_menu_director.gd`
   - `full_menu_shell.gd`
4. Run the usual dev scene.
5. Open the full menu with `Tab` or `M`.
6. Confirm there is a `Stats` tab.
7. Confirm the Stats tab shows:
   - Action Resources
   - Physical Offense
   - Magic Offense
   - Protection and Recovery
   - Utility
   - Natural Affinities
   - Primal Affinities
   - Vital Affinities
   - Mystical Affinities
   - Primordial Affinities
8. Press number keys 1-5 and confirm tab jumping still works.
9. Close the menu and confirm gameplay resumes.
10. Cast a few spells and confirm existing mana/stat UI still updates.
11. Press restart after defeat and confirm health/mana/stamina/stance reset to useful values instead of all becoming 1.

## Future hooks

Later passes can add fields like:

```text
AbilityDefinition.scaling_stats = ["arcana", "fire"]
WeaponDefinition.scaling_stats = ["power", "dexterity"]
AugmentDefinition.required_stats = ["intelligence", "dreams"]
StatusEffect.scaling_stat = "constitution"
```

For now, this pass just gives those future systems stable shelves to sit on.
