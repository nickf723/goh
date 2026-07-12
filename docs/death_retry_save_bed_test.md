# Death Retry From Save Bed v1 Test

## Goal

Confirm the first fail / retry loop:

```text
sleep at bed -> save -> get defeated -> reload -> wake at bed -> try again
```

This keeps saving diegetic: Grace saves by sleeping, and defeat sends her back to the last sleep point.

## Files changed

- `scripts/systems/death_retry_from_save.gd`
- `scripts/levels/prototype_mini_dungeon_chain.gd`

## Test scene

Open:

```text
scenes/levels/prototypes/prototype_mini_dungeon_chain_v1.tscn
```

Run Current Scene.

## Test A: no save yet

1. Delete the local save file if needed:
   - `user://goh_save_slot_1.json`
   - Exact location depends on Godot's user data folder.
2. Run the mini-dungeon scene.
3. Do **not** sleep in the bed.
4. Let Grace get defeated.
5. Expected:
   - Grace does not reload from a save.
   - A message says no saved rest was found.
   - Existing defeated behavior remains available.

## Test B: saved retry loop

1. Run the mini-dungeon scene.
2. Use the bed near the mana shrine.
3. Confirm the save message appears.
4. Enter the combat room.
5. Let Grace get defeated.
6. Expected before reload:
   - A message appears: Grace falls and the last bed calls her back.
7. Wait about one second.
8. Expected after reload:
   - The mini-dungeon scene reloads.
   - Grace wakes at the entry save bed.
   - Resources are restored from the saved bed state.
   - Mouse control is captured again by the scene.
9. Continue into the dungeon and clear it normally.

## Test C: dungeon state reset

1. Sleep at the bed.
2. Defeat one enemy if possible.
3. Let Grace get defeated.
4. Confirm the scene reloads from the save.
5. Expected:
   - The combat room resets because the scene reloads.
   - Enemies and gates are fresh.

## Expected player-facing loop

```text
Sleep at bed.
Progress saved.
Grace falls.
Scene reloads.
Grace wakes at bed.
Try again.
```

## Known limitations

- One save slot only.
- Death retry is enabled for the mini-dungeon scene via its level director.
- It reloads the full scene instead of saving partial dungeon state.
- No death screen UI yet.
- No fade-to-black yet.
- No save-slot menu yet.
