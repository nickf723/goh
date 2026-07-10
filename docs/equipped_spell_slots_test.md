# Equipped Spell Slots v1 Test Plan

## Goal

Give the spell system a clearer loadout structure without removing the current prototype spell access.

This pass separates three ideas that were previously blurred together:

```text
Learned Spell Library
All spells Grace knows.

Equipped Combat Slots
The smaller combat-facing loadout shelf.

Active Test Ring
The current prototype list AbilityCaster still uses for selection and focus-menu testing.
```

## What changed

### `scripts/abilities/ability_loadout.gd`

Adds structural helpers:

- `quick_slot_count`
- `get_quick_slot_count()`
- `get_equipped_slot_rows()`
- `get_learned_abilities()`
- `get_learned_spell_sections()`
- `get_unassigned_learned_abilities()`

The existing `learned_abilities` and `equipped_abilities` fields remain intact.

### `data/loadouts/grace_starting_loadout.tres`

- Sets `quick_slot_count = 8`.
- Keeps all current spells learned.
- Keeps all current spells in the active equipped list for prototype testing.

### `scripts/ui/full_menu_director.gd`

Sends new menu data:

- `equipped_spell_slots`
- `learned_spell_sections`
- `loadout_summary`

### `scripts/ui/full_menu_shell.gd`

Updates the Loadout tab to show:

- Loadout summary.
- Equipped Combat Slots.
- Current weapon.
- Learned Spell Library grouped by element.

## How to test

1. Pull branch `agent/equipped-spell-slots-v1`.
2. Open Godot.
3. Confirm no parser errors from:
   - `ability_loadout.gd`
   - `full_menu_director.gd`
   - `full_menu_shell.gd`
4. Run the usual dev scene.
5. Open the full menu with `Tab` or `M`.
6. Open `Loadout`.
7. Confirm the top summary shows:
   - equipped combat slots
   - learned spells
   - active test ring
8. Confirm `Equipped Combat Slots` shows the first 8 slots.
9. Confirm the weapon still appears.
10. Confirm `Learned Spell Library` appears below, grouped by element.
11. Confirm empty element shelves display `No learned spells yet`.
12. Close the menu.
13. Confirm focus spell menu and spell casting still behave as before.
14. Confirm number hotkeys and next-spell cycling still work as before.

## Current design choice

This PR intentionally does **not** reduce gameplay access to only eight spells yet.

The menu now introduces the idea of combat-facing slots, but `AbilityCaster` still reads the full `equipped_abilities` list so the current spell playground remains available.

That gives us the cabinet before we start locking spells into drawers.

## Future hooks

Later passes can add:

```text
Loadout swapping
Menu-driven spell assignment
Element presets
Locked spell slots
Augment slots per equipped spell
Combat slot limits
Favorite slots
Controller-friendly slot editing
```

## Known risks

- I could not run Godot here, so parser/resource testing is needed.
- The learned library is display-only for now.
- `quick_slot_count` only affects menu structure in this pass.
- The active test ring is still larger than the displayed combat slots on purpose.
