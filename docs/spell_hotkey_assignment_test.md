# Spell Hotkey Assignment v1 Test

## Goal

Turn the full menu from display-only structure into the first usable equipment workbench.

This pass wires spell assignment only:

```text
Equipment hotkey slot -> Spellbook learned spell -> updated spell hotkey
```

Items, weapons, gadgets, augments, and inventory assignment stay out of scope.

## What changed

- Equipment spell hotkey rows are selectable buttons.
- Spellbook rows become selectable while assigning a spell.
- Selecting a spell hotkey enters spell assignment mode.
- Choosing a learned spell assigns it to the pending hotkey slot.
- `AbilityLoadout.equip_ability(slot, spell)` performs the actual swap.
- The menu refreshes after assignment.
- `AbilityCaster.select_ability(slot)` is called after assignment so the UI and current spell update.
- `Esc` cancels assignment mode before closing the menu.

## Expected flow

1. Open the full menu with `Tab` or `M`.
2. Open `Equipment`.
3. Select a spell hotkey row with `W/S`, arrow keys, or mouse.
4. Press `Enter` or click the row.
5. The menu jumps to `Spellbook` in assignment mode.
6. Select a learned spell.
7. Press `Enter` or click it.
8. The menu returns to `Equipment`.
9. The chosen spell now appears in the selected hotkey slot.

## Controls

```text
A/D or left/right: switch tabs
W/S or up/down: move row selection
Enter or click: choose current row
Esc: cancel assignment, or close menu when not assigning
1-7: jump tabs
```

## Test steps

1. Pull branch `agent/spell-hotkey-assignment-v1`.
2. Open Godot.
3. Confirm no parser errors from:
   - `full_menu_director.gd`
   - `full_menu_shell.gd`
4. Run the usual dev scene.
5. Open the full menu with `Tab` or `M`.
6. Open `Equipment`.
7. Select `Spell Hotkey 1`.
8. Press `Enter`.
9. Confirm the menu switches to `Spellbook` and shows assignment instructions.
10. Pick a learned spell that is not currently in slot 1 if possible.
11. Press `Enter` or click the spell row.
12. Confirm the menu returns to `Equipment`.
13. Confirm `Spell Hotkey 1` now shows the selected spell.
14. Close the menu.
15. Cast a spell and confirm the selected hotkey spell can be used.
16. Reopen the menu and test another slot.
17. Enter assignment mode again and press `Esc`.
18. Confirm assignment is canceled without changing the slot.

## Regression checks

- Tabs still switch with `A/D`, arrows, and `1-7`.
- Spellbook still shows compact rows grouped by element.
- Inventory still shows compact placeholder rows.
- Stats, Journal, Codex, and System still render.
- Focus spell selector still opens and casts.
- Game resumes after closing the full menu.

## Known limitations

- Assignment is runtime-only for now. It does not save across editor reloads.
- Items, weapons, gadgets, and augments are not assignable yet.
- There is no spell inspector panel yet.
- Drag-and-drop is not implemented.
- I could not run Godot here, so parser and input testing are needed.
