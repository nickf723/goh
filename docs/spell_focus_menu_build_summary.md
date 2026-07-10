# Spell Focus Menu Build Summary

## What changed

This branch adds a prototype two-step spell quick menu that opens during focus time.

The player can now:

1. Hold focus.
2. Choose one of the 16 core elements.
3. Choose a learned/equipped spell under that element.
4. Confirm the highlighted spell to equip it.
5. Release focus and cast normally.

## Files changed

- `scripts/abilities/ability_caster.gd`
  - Owns the 16-element menu data.
  - Groups elements into Natural, Primal, Vital, and Mystical.
  - Tracks selected element and selected spell.
  - Confirms the highlighted spell without casting it immediately.

- `scripts/player/player_controller.gd`
  - Routes input to AbilityCaster while the focus spell menu is open.
  - Prevents Q from casting while the menu is open, so Q confirms instead.
  - Prevents mouse movement from rotating the camera while choosing spells.

- `scripts/systems/focus_time.gd`
  - Cleans up duplicated focus logic.
  - Opens/closes the spell quick menu when focus starts/stops.

- `scripts/ui/game_ui.gd`
  - Renders the focus spell menu as a text-first prototype.

- `scenes/ui/game_ui.tscn`
  - Expands the spell menu label area so the 16-element menu can be read.

- `docs/spell_focus_menu_test.md`
  - Adds a test plan.

## Controls

Hold focus with Left Shift or Right Mouse Button, then use:

- Left / Right Arrow: element selection.
- Up / Down Arrow: spell selection.
- Mouse Wheel: spell selection.
- Enter / Space / Q / Left Click: equip highlighted spell.

## Notes

This is intentionally a readable text prototype. It gives us the behavior and data shape for the eventual radial/flashier menu without requiring final UI art yet.
