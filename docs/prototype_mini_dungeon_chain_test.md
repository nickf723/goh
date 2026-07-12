# Prototype Mini-Dungeon Chain Test

## Goal

Test the first tiny dungeon flow instead of a single isolated room.

```text
Room 1: safe shrine / entry
Room 2: combat + readable gate
Room 3: element lock puzzle + final exit
```

This is not final dungeon design. It is a progression and readability test.

## Scene

Open:

```text
scenes/levels/prototypes/prototype_mini_dungeon_chain_v1.tscn
```

Run Current Scene.

## Expected flow

1. Spawn in the entry room.
2. Notice the mana shrine and warm cover blocks.
3. Move through the open doorway into the combat room.
4. Defeat the Goblin and Gremlin.
5. Confirm the combat gate's blue barrier disappears while the gold frame remains.
6. Enter the puzzle room.
7. Hit the blue Water Lock with a water spell.
8. Hit the black Fire Lock with a fire spell.
9. Confirm the final gate barrier disappears.
10. Step onto the gold exit pad.
11. Confirm the mini-dungeon completion message appears.

## Visual language being tested

```text
Gray floor      = walkable stone
Dark walls      = room boundary
Warm blocks     = cover / pillars / collision
Black glossy    = oil / fire logic / fire lock hint
Blue patch      = water / water logic / water lock hint
Cyan glow       = mana shrine
Gold frame      = gate structure
Blue barrier    = locked magic wall
Gold marker     = active lock / exit goal
```

## Specific checks

### Room 1

- The shrine room should feel safe.
- The objective should say this is a mini-dungeon chain.
- The readable material language should be clear before combat begins.

### Room 2

- Enemies should be able to path and attack normally.
- The oil and water patches should still be visible/readable.
- The combat gate should not open until both enemies are defeated.
- The gate frame should remain after the barrier disappears.

### Room 3

- The blue target should clearly read as the Water Lock.
- The black target should clearly read as the Fire Lock.
- Wrong elements should give feedback.
- Correct elements should show a gold active marker.
- The final gate should not open from combat clearing alone.
- The final gate should open only after both lock targets activate.

## Controls regression

Confirm the controller fixes still work:

- Left stick moves.
- Right stick controls camera.
- ZL / left trigger opens focus spell selector.
- D-pad navigates focus selector.
- ZR / right trigger confirms/casts.

## Tuning questions

- Does the 3-room layout feel understandable?
- Is the distance between rooms too long, too short, or fine?
- Does Room 3 read as a puzzle without extra explanation?
- Are the Water and Fire lock targets too easy to hit?
- Does the final exit feel like a reward endpoint?

## Known limitations

- Uses primitives only.
- Puzzle locks are simple spell-hit checks, not a full puzzle system.
- There is no checkpoint or death reset pass here.
- I could not run Godot here, so parser and scene validation are needed.
