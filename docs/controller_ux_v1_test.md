# Controller UX v1 Test

## Goal

Make the prototype UI respond to the player's current input device.

```text
keyboard/mouse input -> keyboard prompts
controller input -> controller prompts
```

This is intentionally small and stacked after the spell menu select fix.

## What changed

- `scripts/ui/game_ui_controller_prompts.gd`
  - Extends the existing `GameUI` script.
  - Tracks the last active input mode from keyboard, mouse, and joypad events.
  - Adds a small `Input: Keyboard / Mouse` or `Input: Controller` label.
  - Rewrites interact prompts as `E: ...` or `B: ...` depending on the active input mode.
  - Updates the focus spell menu help copy for keyboard or controller.
  - Changes the focus spell selected label from `Cast:` to `Selected:`.
- `scenes/ui/game_ui.tscn`
  - Uses the controller-aware UI wrapper script.
- `scripts/levels/prototype_upgrade_lab.gd`
  - Updates the opening lab message with keyboard and controller controls.

## Fast test scene

Open:

```text
scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn
```

## Test flow

1. Run Current Scene.
2. Touch the keyboard or mouse.
3. Confirm the top-right input label says `Input: Keyboard / Mouse`.
4. Stand near an interactable pedestal.
5. Confirm the prompt uses `E:`.
6. Press a controller button or move a stick/trigger.
7. Confirm the input label changes to `Input: Controller`.
8. Stand near an interactable pedestal.
9. Confirm the prompt switches to `B:`.
10. Hold the spell menu / focus input.
11. Confirm the focus spell menu help copy uses controller controls.
12. Press keyboard input again.
13. Confirm the menu help copy switches back to keyboard controls.
14. Confirm the spell menu still equips without firing, from PR #90.
15. Confirm regular casting, charged Firebolt, and feedback haptics still work.

## Regression checks

- Interact still works with keyboard.
- Interact still works with controller.
- The spell menu still opens and closes.
- Selecting a spell from the menu still equips without spending mana.
- Normal casting outside the menu still fires the equipped spell.
- The charge meter still appears for Charged Firebolt.

## Known limitations

- Controller prompt names assume the current prototype mapping: `B` for interact, trigger for cast/focus.
- This is UI detection only, not a full rebinding screen.
- I could not run Godot here, so parser and scene validation are needed.
