# Equipment + Spellbook Menu Structure v1

## Goal

Split the full menu into clearer rooms so the Loadout tab is no longer a crowded pile of spells, weapons, and future item systems.

This pass makes the conceptual split visible:

```text
Equipment
What Grace has ready.

Spellbook
What Grace knows.

Inventory
What Grace owns.
```

The main gameplay behavior should remain unchanged for now.

## What changed

- Renames/reframes the old `Loadout` tab as `Equipment`.
- Adds a separate `Spellbook` tab.
- Adds an `Inventory` placeholder tab.
- Keeps `Stats`, `Journal`, `Codex`, and `System` tabs.
- Equipment now shows:
  - ready equipment summary
  - weapon slot
  - spell hotkeys
  - item hotkey placeholders
  - gadget/tool/summon placeholders
- Spellbook now shows:
  - learned spells grouped by element
  - equipped/hotkey suffixes for spells that are already in the active ring
- Inventory now shows placeholder sections for:
  - item hotkey source
  - consumables
  - materials
  - key items

## New menu map

```text
Equipment
- Weapon Slot
- Spell Hotkeys
- Item Hotkeys
- Gadget Slots

Spellbook
- Learned spells grouped by element
- Future assignment source for spell hotkeys

Inventory
- Consumables
- Materials
- Key Items
- Future assignment source for item hotkeys

Stats
Journal
Codex
System
```

## Current behavior

This is still structure-first.

- Spell hotkey assignment is not wired yet.
- Item assignment is not wired yet.
- Inventory has no real item database yet.
- AbilityCaster should still use the active prototype ring so current spell testing remains easy.

## Future intended flows

### Equipment-first assignment

```text
Open Equipment
Choose Spell Hotkey 1
Choose a spell from Spellbook
Spell Hotkey 1 becomes Firebolt
```

### Spellbook-first assignment

```text
Open Spellbook
Choose Firebolt
Choose Assign
Pick Spell Hotkey 1
Spell Hotkey 1 becomes Firebolt
```

The first flow is probably cleaner to build first.

## How to test

1. Pull branch `agent/equipment-spellbook-menu-v1`.
2. Open Godot.
3. Confirm no parser errors from `full_menu_shell.gd`.
4. Run the usual dev scene.
5. Open the full menu with `Tab` or `M`.
6. Confirm the side tabs are:
   - Equipment
   - Spellbook
   - Inventory
   - Stats
   - Journal
   - Codex
   - System
7. Confirm `1-7` jump to each tab.
8. Open `Equipment`.
9. Confirm it shows:
   - Ready Equipment summary
   - Weapon Slot
   - Spell Hotkeys
   - Item Hotkeys
   - Gadget Slots
10. Open `Spellbook`.
11. Confirm learned spells are grouped by element.
12. Open `Inventory`.
13. Confirm placeholder inventory categories appear.
14. Cast spells and use the focus spell selector to confirm gameplay behavior is unchanged.

## Known risks

- I could not run Godot here, so parser testing is needed.
- The new tabs are menu structure only.
- No click-to-assign behavior exists yet.
- Inventory and items are placeholders until an item database exists.
