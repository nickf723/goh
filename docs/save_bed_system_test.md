# Save Bed System Test

## Goal

Add the first diegetic save mechanic:

```text
Grace saves by sleeping in a bed.
```

This is Save Bed v1. It is intentionally simple and prototype-readable.

## What changed

- `scripts/systems/game_state.gd`
  - Adds one persistent save slot at `user://goh_save_slot_1.json`.
  - Saves current scene path.
  - Saves bed id/name.
  - Saves bed position.
  - Saves current stats.
  - Saves story flags.
  - Saves current objective.
  - Can apply saved data when the matching scene loads.
- `scripts/interaction/save_bed.gd`
  - Adds an interactable save bed.
  - Sleeping restores health, mana, stamina, and stance.
  - Sleeping writes the save file.
- `scenes/actors/interactables/save_bed.tscn`
  - Adds a simple colored prototype bed asset.
- `scripts/levels/prototype_mini_dungeon_chain.gd`
  - Spawns an entry save bed in Room 1.
  - Applies the saved position/data when the mini-dungeon scene loads and the saved scene path matches.

## Save behavior

Interact with the bed:

```text
Grace sleeps.
Resources restore.
Save file writes.
The current scene and bed position are stored.
```

Reload the same scene:

```text
Saved stats/objective/flags load.
Grace is moved to the saved bed position.
```

## How to test

1. Pull branch `agent/save-bed-system-v1`.
2. Open Godot.
3. Open `scenes/levels/prototypes/prototype_mini_dungeon_chain_v1.tscn`.
4. Run Current Scene.
5. Find the bed in Room 1 near the mana shrine.
6. Walk into its interaction area.
7. Confirm the prompt says `Sleep / Save`.
8. Press interact.
9. Confirm the message says Grace sleeps and progress is saved.
10. Spend mana or take damage if convenient.
11. Stop and run the same scene again.
12. Confirm the scene says Grace wakes at the last save bed.
13. Confirm Grace appears at the bed location.
14. Confirm resources match the saved/rested state.
15. Continue and clear the dungeon normally.

## Expected result

The bed should feel like a save point, not a menu button:

```text
bed = sleep + restore + save + future wake-up point
```

## Known limitations

- One save slot only.
- No save/load menu yet.
- No delete-save button yet.
- Does not yet save defeated enemies or opened gates.
- It restores Grace and position, but dungeon state resets on reload for now.
