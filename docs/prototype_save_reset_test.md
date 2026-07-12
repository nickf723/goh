# Prototype Save Reset Test

## Goal

The key-item save system is now doing exactly what we want: once Grace claims the Church Trial Sigil, future runs start with that saved progress.

That is good for persistence, but inconvenient when testing the missing-sigil exit path.

This pass adds a tiny prototype-only reset affordance:

```text
Press F8 -> clear one-slot prototype save -> reset GameState -> reload scene fresh
```

## Scene

Open:

```text
scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn
```

Run Current Scene.

## What changed

- Updates `scripts/levels/prototype_boss_dungeon_chain.gd`.
- Adds `PROTOTYPE_SAVE_PATH = "user://goh_save_slot_1.json"`.
- Adds `enable_dev_save_reset` export.
- Adds an `_unhandled_input` handler for `F8`.
- When F8 is pressed:
  - `GameState.reset_run()` clears runtime flags, stats, and key items.
  - The one-slot save file is deleted if it exists.
  - The scene reloads after a short delay.

## Test flow: clear old sigil save

1. Run the boss dungeon chain scene after previously claiming the sigil.
2. Confirm Grace resumes from saved progress.
3. Press `F8`.
4. Confirm a message says the prototype save was cleared.
5. Confirm the scene reloads.
6. Confirm Grace starts at the beginning without the sigil.

## Test flow: missing-sigil gate

1. Clear the save with `F8`.
2. Defeat the Animated Armor.
3. Walk around the reward altar if possible.
4. Step on the final exit before claiming the sigil.
5. Confirm the exit says it waits for the Church Trial Sigil.
6. Claim the sigil.
7. Step on the final exit again.
8. Confirm the Church Trial completes.

## Expected result

The same scene now supports both testing styles:

```text
normal saved progression -> Grace keeps the sigil
fresh prototype test -> F8 clears the one-slot save and starts over
```

## Notes

This is intentionally prototype-only. A real game would expose this as a New Game, Load Game, or save-slot management flow rather than a hidden hotkey.
