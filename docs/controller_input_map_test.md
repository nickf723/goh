# Controller Input Map Test

This branch adds a first controller pass directly in `project.godot` and routes the focus spell selector through InputMap actions.

## Goal

Make the Switch controller usable without manually configuring Godot's Input Map first.

## Expected controller layout

This uses Godot's standard controller button positions. Switch labels may display differently depending on driver/Steam/Input settings, so treat this as a physical-position map first.

- Left stick: move.
- ZL / left trigger: hold focus spell selector.
- ZR / right trigger: confirm highlighted spell in focus selector, cast equipped spell outside focus.
- D-pad left/right: change element in the focus selector.
- D-pad up/down: change spell in the selected element.
- Bottom face button: dodge.
- Right face button: interact.
- Left face button: light attack.
- Top face button: jump.

Fallbacks:

- Left shoulder also opens focus if Godot reports ZL differently.
- Right shoulder also casts/confirms if Godot reports ZR differently.

## Keyboard/mouse still works

- Shift or right mouse: focus.
- Arrow keys: navigate focus selector.
- Mouse wheel: change spell.
- Q / Enter / Space / click: confirm highlighted spell.
- Q outside focus: cast equipped spell.

## Test path

1. Pull `agent/hazard-reactions-v1`.
2. Connect the Switch controller before running the scene.
3. Run the usual dev scene.
4. Confirm left stick moves Grace.
5. Hold ZL. If it does not open focus, try L.
6. Use D-pad to navigate elements/spells.
7. Press ZR. If it does not confirm/cast, try R.
8. Release focus and press ZR again to cast the equipped spell.
9. Test bottom face button for dodge, left face button for attack, right face button for interact.

## What to report back

If a button is wrong, report it by physical position, not just label. Example:

- "ZL does nothing, but L opens focus."
- "ZR does nothing, but R casts."
- "Bottom button jumps instead of dodging."
- "D-pad left/right does not move the selector."

That will let us patch the map quickly without guessing which driver labels the Switch controller is using.
