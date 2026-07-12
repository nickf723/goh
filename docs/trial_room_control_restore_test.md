# Trial Room Control Restore Test

## Goal

Restore the control mappings that the church trial room needs for real playtesting:

- focus spell selector
- controller focus navigation
- controller casting
- controller camera look
- missing fallback actions used by player scripts

The trial room felt good, but controls got thinned out when the branch pointed straight at the new room. This patch keeps the room and restores the input surface around it.

## Files changed

- `project.godot`

## Restored / added actions

### Focus and spell menu

- `spell_menu`
  - keyboard: Shift
  - mouse: right mouse
  - controller: left trigger axis 4
  - controller fallback: left shoulder button 9

### Cast / confirm

- `cast_spell`
  - keyboard: Q
  - controller: right trigger axis 5
  - controller fallback: right shoulder button 10

### Focus menu navigation

- `focus_element_left`
  - D-pad left, button 13
- `focus_element_right`
  - D-pad right, button 14
- `focus_spell_up`
  - D-pad up, button 11
- `focus_spell_down`
  - D-pad down, button 12

### Controller camera

- `camera_left`
  - right stick X negative, axis 2
- `camera_right`
  - right stick X positive, axis 2
- `camera_up`
  - right stick Y negative, axis 3
- `camera_down`
  - right stick Y positive, axis 3

### Missing fallbacks

- `ability_slot_9`
- `ability_slot_0`
- `next_ability`
- `restart_scene`

## How to test

1. Pull branch `agent/restore-trial-room-controls-v1`.
2. Open Godot.
3. Run the church trial room.
4. Confirm keyboard movement, casting, attacking, dodge, and interact still work.
5. Hold Shift or right mouse and confirm focus time / spell selector opens.
6. Connect controller.
7. Confirm left stick moves Grace.
8. Confirm right stick moves the camera.
9. Hold ZL / left trigger and confirm focus selector opens.
10. If ZL does not work, try L / left shoulder.
11. Use the D-pad to move through the focus selector.
12. Press ZR / right trigger to confirm or cast.
13. If ZR does not work, try R / right shoulder.
14. Fight through the room again.

## What to report

If the right stick still does not work, report whether it is:

- no movement at all
- horizontal only
- vertical only
- inverted
- constantly drifting

If focus still does not work, report whether:

- ZL does nothing
- L does nothing
- right mouse works
- Shift works

That will tell us whether the controller driver is using nonstandard axis/button indices.
