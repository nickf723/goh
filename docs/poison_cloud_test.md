# Poison Cloud Test

## Goal

Add a first lingering area spell that creates a toxic field, applies `poisoned`, and damages enemy health over time.

## Controls

```txt
F9/F10: cycle dev scenarios
F6: spawn selected scenario
7: equip Poison Cloud
Q: cast Poison Cloud
F7: clear spawned enemies
```

## Test path

1. Pull branch `agent/poison-cloud-v2`.
2. Open the usual dev scene.
3. Use `F9` or `F10` until the selected scenario is `Poison Cloud Lab`.
4. Press `F6` to spawn the lab enemies.
5. Press `7` to equip `Poison Cloud`.
6. Press `Q` while facing the enemies.
7. Watch for a green cloud and poison tick messages.

## Expected behavior

- Poison Cloud appears a few steps in front of Grace.
- Enemies inside the cloud gain `poisoned`.
- Poison ticks health directly over time.
- The cloud fades after a few seconds.
- Slot 7 appears in the spell menu/loadout as `Poison Cloud`.

## Notes

This is the reusable foundation for future lingering area spells: fire fields, dream fog, sound resonance zones, healing auras, and time bubbles.
