# Spell Selector UI Test

## Goal

Replace the text-only focus spell menu with a clearer visual selector.

## Branch

`agent/spell-selector-ui-v1`

## What changed

- `scripts/ui/game_ui.gd`
  - Builds a runtime `FocusSpellSelectorPanel` instead of relying on the old text label.
  - Displays the 16 elements as colored tiles in a 4x4 grid.
  - Highlights the currently selected element.
  - Shows the selected element's learned spells in a separate spell list panel.
  - Highlights the currently selected spell.
  - Keeps the existing input flow from the focus menu branch.

## Controls

Hold focus with Left Shift or Right Mouse Button, then:

- Left / Right Arrow: change element.
- Up / Down Arrow: change spell under the selected element.
- Mouse Wheel: change spell under the selected element.
- Q / Enter / Space / Left Click: equip highlighted spell.
- Release focus: close the menu.
- Press Q after release: cast the equipped spell.

## Expected behavior

- Holding focus opens a centered visual spell selector panel.
- The 16 elements appear as colored tiles.
- Fire, Air, Poison, Sound, Space, Ice, Lightning, and other learned elements should be browsable if spells exist for them.
- Empty elements should show an empty-shelf message without errors.
- The old text-only menu should not overlap the new selector.
- Releasing focus closes the visual selector.

## Known risks

- This is still a prototype UI, built dynamically in `game_ui.gd` to avoid scene-file hand editing.
- The layout may need resizing after one real monitor/game-window pass.
