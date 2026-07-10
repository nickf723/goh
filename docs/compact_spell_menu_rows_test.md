# Compact Spell Menu Rows v1 Test

## Goal

Condense spell/equipment/spellbook menu rows so the menu reads more like an RPG inventory list and less like a full inspection form.

This pass prepares the UI for future assignment behavior by making rows easier to scan.

## What changed

- `scripts/ui/full_menu_shell.gd`
  - Converts spell hotkeys to compact one-line rows.
  - Converts Spellbook entries to compact one-line rows.
  - Shortens the Equipment summary.
  - Keeps longer spell metadata out of the default row view.
  - Adds compact rendering helpers:
    - `add_compact_card`
    - `get_spell_compact_line`
    - `get_spell_cost_label`
    - `get_scaling_label`
    - `get_short_list_label`
  - Keeps the existing tabs:
    - Equipment
    - Spellbook
    - Inventory
    - Stats
    - Journal
    - Codex
    - System

## Row format

Spell rows now try to fit on one line:

```text
Spell Hotkey 1  ·  Firebolt  ·  Fire  ·  M1  ·  Arc/Fire  ·  damage/projectile
```

Spellbook rows use the same grammar:

```text
Known  ·  Dream Snare  ·  Dreams  ·  M1  ·  Int/Drm  ·  control/status
```

Weapon rows are also compact:

```text
Weapon  ·  Practice Sword  ·  Sword  ·  dmg 1 / stance 1  ·  Pow/Dex
```

## How to test

1. Pull branch `agent/compact-spell-menu-rows-v1`.
2. Open Godot.
3. Confirm no parser errors from `full_menu_shell.gd`.
4. Run the usual dev scene.
5. Open the full menu with `Tab` or `M`.
6. Open `Equipment`.
7. Confirm spell hotkeys show compact one-line rows.
8. Confirm rows include:
   - slot label
   - spell name
   - element
   - cost
   - scaling
   - short role list
9. Open `Spellbook`.
10. Confirm spells are grouped by element and each spell is one compact row.
11. Confirm long fields like profile, combo tags, status tags, scaling note, and design notes are not cluttering the default row view.
12. Open `Inventory` and confirm placeholders are compact rows.
13. Open `Stats`, `Journal`, `Codex`, and `System` to make sure they still render.
14. Cast spells and use the focus spell selector to confirm gameplay behavior is unchanged.

## Known limitations

- Rows are display-only.
- No click-to-assign yet.
- No spell inspector panel yet.
- Some rows may still visually clip if the window is narrow or a spell name becomes very long.
- Detailed spell data still exists in resources, but it is intentionally not shown in the default list view.

## Future hook

The next pass can add an inspector panel or tooltip:

```text
Select Firebolt row
Inspector shows full description, profile, combo tags, status tags, scaling note, and design notes
```

That keeps the list compact while preserving the rich data when the player actually asks for it.
