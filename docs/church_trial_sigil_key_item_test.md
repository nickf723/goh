# Church Trial Sigil Key Item Test

## Goal

Make the Church Trial Sigil into a real progression item instead of only a completion flag.

```text
claim sigil -> key item stored -> save persists it -> final exit requires it
```

This is the first pass at game substance layered on top of the boss-chain mechanics.

## Scene

Open:

```text
scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn
```

Run Current Scene.

## What changed

- `GameState`
  - Adds a simple key item dictionary.
  - Adds `add_key_item`, `has_key_item`, `remove_key_item`, `get_key_item_rows`, and save/load support.
  - Adds backward compatibility so a save with `claimed_church_trial_sigil = true` counts as having the key item.
- `ChurchTrialRewardAltar`
  - Awards `church_trial_sigil` as a key item.
  - Adds a short lore message when Grace claims the sigil.
  - Saves the sigil in the existing one-slot save file.
- `LevelExit`
  - Can now require a key item.
  - Shows a blocked message and objective when Grace lacks the required item.
- `PrototypeBossDungeonChain`
  - Configures the final exit to require `church_trial_sigil`.

## Main test flow

1. Run the boss dungeon chain scene.
2. Sleep in the entry save bed.
3. Clear the combat room.
4. Solve the Fire + Water lock.
5. Sleep before the boss.
6. Defeat the Animated Armor.
7. Confirm the boss exit gate opens.
8. Try stepping on the final exit pad before claiming the altar, if possible.
9. Confirm the exit says it is waiting for the Church Trial Sigil.
10. Claim the reward altar.
11. Confirm the message includes the Church Trial Sigil lore beat.
12. Confirm resources restore and progress saves.
13. Step onto the final exit pad.
14. Confirm the Church Trial completes.

## Resume test

1. After claiming the sigil, stop and run the scene again.
2. Confirm Grace resumes from saved progress near the reward altar.
3. Step onto the final exit pad.
4. Confirm the exit accepts the saved sigil and completes the trial.

## Backward-compatibility test

Use a save from the previous reward-altar pass, if one exists:

```text
claimed_church_trial_sigil = true
key_items missing
```

Expected result:

```text
GameState.has_key_item("church_trial_sigil") returns true
final exit allows completion
future autosaves include the key_items dictionary
```

## Known limitations

- The full inventory UI still needs a dedicated Key Items screen.
- The key item data is stored and queryable now, but the inventory tab display is still a later UI polish pass.
- One save slot only.
- The sigil is still primitive art.
- I could not run Godot here, so parser and scene validation are needed.
