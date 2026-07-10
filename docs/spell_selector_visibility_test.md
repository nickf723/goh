# Spell Selector Visibility Pass Test

## Goal

Make the focus spell selector usable during combat instead of covering the whole screen.

## What changed

- The focus spell selector now appears as a compact bottom-center overlay.
- The main panel and inner panels are semi-transparent.
- Element tiles are smaller and less text-heavy.
- Spell rows are shorter and cleaner.
- The selected element and selected spell remain strongly highlighted.
- The selector fades in quickly when focus opens.
- The old text fallback is still present for safety.

## How to test

1. Pull branch `agent/spell-selector-visibility-v1`.
2. Run the usual dev scene.
3. Select `Hazard Combo Lab` with `F9` / `F10`.
4. Press `F6` to spawn enemies.
5. Hold `ZL` / focus.
6. Confirm the selector appears near the bottom-center instead of covering the middle of the screen.
7. Confirm the world remains visible behind the panel.
8. Use D-pad to navigate elements and spells.
9. Press `ZR` to quick-cast from the selector.
10. Try Poison Cloud -> Fire Field -> Wind Gust while keeping enemies/hazards visible.

## Expected behavior

- The selector should no longer block the entire combat view.
- Grace, enemies, and hazard fields should remain visible through and above the UI.
- D-pad navigation still works.
- ZR/Q quick-cast still works.
- Empty elements still display safely.

## Tuning notes

If it is still too large, reduce the panel offsets in `ensure_focus_spell_selector_ui()`.

If it is too transparent, increase `PANEL_BACKGROUND.a` and `INNER_PANEL_BACKGROUND.a` in `scripts/ui/game_ui.gd`.

If selected items are not obvious enough, increase selected border width or selected row alpha.
