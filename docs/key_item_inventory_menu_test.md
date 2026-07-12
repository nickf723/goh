# Key Item Inventory Menu Test

## Goal

Verify that the full menu displays owned key items from `GameState` and that the Church Trial Sigil survives the save/load loop.

## Empty-state test

1. Open `scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn`.
2. Run Current Scene.
3. Press `F8` if Grace resumes with an old Church Trial Sigil save.
4. Open the full menu with `Tab` or `M`.
5. Select `Inventory` with tab navigation or key `3`.
6. Confirm the `Key Items` section says `Grace has no key items yet.`
7. Confirm the remaining inventory placeholders appear under `Future Inventory`.

## Sigil acquisition test

1. Complete the combat and Fire + Water lock sections.
2. Defeat the Animated Armor.
3. Claim the Church Trial Sigil from the reward altar.
4. Open the full menu and select `Inventory`.
5. Confirm a compact row appears with:

```text
Church Trial Sigil  ·  Trial Relic  ·  First Church Trial
```

6. Confirm the row is labeled `Key Item`.
7. Navigate through Equipment, Spellbook, Stats, Journal, Codex, and System.
8. Confirm keyboard/controller menu navigation still behaves normally.

## Persistence test

1. Close and restart the same prototype scene after claiming the sigil.
2. Confirm saved progress loads.
3. Open `Inventory` again.
4. Confirm the Church Trial Sigil row still appears with the same name, kind, and source.

## Expected result

The Inventory tab reads key-item rows from `GameState`. Empty saves show a clear empty state, while acquired or backward-compatible saved sigils display using the existing key-item definition.

## Out of scope

- Item use
- Quantities
- Consumables
- Crafting materials
- Item hotkey assignment
- Final icons or inventory art
