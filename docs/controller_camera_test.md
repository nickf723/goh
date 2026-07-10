# Controller Camera Test

## Goal

Add right-stick camera control for the connected Switch controller.

This follows the existing controller pass:

- Left stick moves Grace.
- ZL / L opens the focus spell selector.
- ZR / R confirms/casts spells.
- D-pad navigates the focus selector.

This pass adds:

- Right stick left/right rotates Grace/camera yaw.
- Right stick up/down tilts the camera pitch.

## Files changed

- `project.godot`
- `scripts/player/player_controller.gd`

## Input actions added

- `camera_left`
- `camera_right`
- `camera_up`
- `camera_down`

Default axis mapping:

- Right stick X: joypad axis `2`
- Right stick Y: joypad axis `3`

## How to test

1. Pull branch `agent/controller-camera-v1`.
2. Run the usual dev scene.
3. Move with the left stick.
4. Look around with the right stick.
5. Hold ZL and confirm the focus selector opens.
6. While focus selector is open, confirm right stick camera does not fight menu navigation.
7. Release ZL and confirm right stick camera works again.
8. Confirm ZR still casts outside the focus menu.

## Expected behavior

- Right stick left/right rotates the camera around Grace.
- Right stick up/down tilts the camera.
- Camera pitch clamps like mouse look.
- Focus spell selector still uses D-pad navigation.
- Controller casting/focus behavior remains unchanged.

## Tuning knobs

In `scripts/player/player_controller.gd`:

- `controller_camera_sensitivity`
- `controller_camera_deadzone`
- `allow_controller_camera_during_focus_menu`

## Known risk

Some Switch controller drivers report right stick axes differently. If the right stick does nothing, spins oddly, or only moves on one axis, the likely fix is swapping the axis numbers in `project.godot` for the `camera_*` actions.
