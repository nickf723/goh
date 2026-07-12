# Prototype Visual Assets Room Test

## Goal

Add enough prototype color/material language that objects are readable during gameplay testing without needing final art.

This is not an art pass. It is a visual debugging pass for design.

## New readable language

- Gray stone floor: safe walking surface.
- Dark stone walls: room boundary.
- Warm stone blocks/pillars: cover and collision objects.
- Black glossy patch: oil / flammable status surface.
- Blue patch: water / wet status surface.
- Cyan glow: mana shrine / resource recovery.
- Gold frame: gate structure.
- Blue glowing gate center: locked magic barrier.
- Gold glowing pad: exit volume.

## Files added

- `art/materials/prototype/floor_stone_gray.tres`
- `art/materials/prototype/wall_dark_stone.tres`
- `art/materials/prototype/cover_warm_stone.tres`
- `art/materials/prototype/oil_black_gloss.tres`
- `art/materials/prototype/water_blue_readable.tres`
- `art/materials/prototype/mana_cyan_glow.tres`
- `art/materials/prototype/gate_frame_gold.tres`
- `art/materials/prototype/gate_barrier_blue.tres`
- `art/materials/prototype/exit_gold_glow.tres`
- `scripts/interaction/readable_magic_gate.gd`
- `scripts/levels/prototype_visual_test_room.gd`
- `scenes/actors/interactables/readable_magic_gate.tscn`
- `scenes/levels/prototypes/prototype_visual_test_room_v1.tscn`

## How to test

1. Pull branch `agent/prototype-visual-assets-room-v1`.
2. Open Godot.
3. Open `scenes/levels/prototypes/prototype_visual_test_room_v1.tscn`.
4. Press Run Current Scene.
5. Confirm the room is immediately readable:
   - floor is gray
   - walls are dark
   - cover/pillars are warm stone
   - oil is black
   - water is blue
   - mana shrine has cyan glow
   - gate has gold frame and blue center barrier
   - exit has gold glow
6. Clear both enemies.
7. Confirm the blue gate barrier disappears but the gold frame remains.
8. Walk through the frame into the gold exit pad.
9. Confirm the room completion message appears.

## Things to report

- Does the gate now clearly read as locked vs unlocked?
- Does the barrier disappearing feel obvious?
- Are oil and water easy to distinguish while fighting?
- Does the exit pad read as the goal?
- Are walls/cover clear enough for navigation?
- Any colors that are too bright, too dark, or visually confusing?

## Known limitations

- These are basic Godot primitive assets, not final art.
- The material names are intentionally blunt and readable.
- The old church trial room is left intact; this is a separate visual readability test room.
- The new readable gate keeps its frame after unlock, but only removes the blue barrier/collision.
- I could not run Godot here, so scene/material parser testing is needed.
