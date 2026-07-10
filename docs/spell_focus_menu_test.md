# Spell Focus Quick Menu Test

## Goal

Make spell switching less fiddly by letting Grace choose spells while focus time is active.

## Controls

Hold the existing spell menu/focus input:

- Left Shift
- Right Mouse Button

While holding focus:

- Left / Right Arrow: change element.
- Up / Down Arrow: change spell within the selected element.
- Mouse Wheel: change spell within the selected element.
- Enter / Space / Q / Left Click: equip the highlighted spell.
- Release focus to close the menu and return time to normal.

## Menu structure

The menu shows all sixteen core elements:

- Natural: Water, Earth, Fire, Air
- Primal: Ice, Metal, Lightning, Poison
- Vital: Life, Death, Body, Soul
- Mystical: Dreams, Sound, Space, Time

Only learned/equipped spells appear under the selected element. Empty elements display a placeholder line.

## Current useful test elements

- Fire: Firebolt, Fire Field
- Air: Wind Gust
- Ice: Ice Lance
- Lightning: Lightning Spark
- Poison: Poison Cloud
- Sound: Sound Pulse
- Space: Space Blink

## How to test

1. Pull branch `agent/spell-focus-menu-v1`.
2. Run the usual dev scene.
3. Hold Left Shift or Right Mouse Button.
4. Confirm the focus menu appears and time slows.
5. Use Left/Right Arrow to move across the 16 elements.
6. Use Up/Down Arrow or Mouse Wheel to move through spells in the selected element.
7. Press Enter, Space, Q, or Left Click to equip the highlighted spell.
8. Release focus.
9. Press Q to cast the equipped spell.

## Expected behavior

- The focus menu appears while focus is held.
- Time slows while the menu is open.
- The selected element and highlighted spell are readable.
- Confirming a spell changes the equipped spell without immediately casting it.
- Releasing focus closes the menu.
- Existing number-key spell selection still works outside focus.

## Known risks

- This is a text-first prototype menu, not the final radial UI.
- Arrow keys are used so WASD can remain movement-friendly during focus.
- Gamepad support is not wired yet.
