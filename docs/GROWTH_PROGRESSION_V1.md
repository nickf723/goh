# Growth Progression v1

## Laboratory

Run:

```text
scenes/levels/prototypes/prototype_growth_shrine_lab_v1.tscn
```

Four activity beacons represent Exploration, Combat, Alchemy, and Quest rewards. Each grants a different amount of Experience. Leveling awards a Growth Point and fully restores action resources. The Growth Shrine converts points into permanent, chosen upgrades.

## Progression rules

- Level 1 requires 40 XP to advance.
- Each following level costs 25 more XP than the previous one.
- Excess XP rolls into the next level.
- A sufficiently large reward can grant multiple levels safely.
- Every level grants one Growth Point.
- Experience, Growth Points, level, and upgraded stats persist in bed saves.
- Old saves load with zero current XP and Growth Points.
- Leveling restores Health, Stamina, Mana, and Stance.

## Shrine upgrades

| Growth | Effect | Current prototype limit |
| --- | --- | --- |
| Vitality | +2 maximum Health | 25 |
| Endurance | +2 maximum Stamina | 25 |
| Channeling | +2 maximum Mana | 25 |
| Composure | +2 maximum Stance | 25 |
| Focus | +1 Focus | 15 |
| Presence | +1 Charisma | 10 |

A selection requires two Confirm presses. Cancel backs out of confirmation without spending anything. A Growth Point is consumed only after validation succeeds.

## Controls

- Interact: claim an activity reward or open the shrine
- Up / Down: choose a growth
- Confirm twice: preview and apply
- Cancel: cancel confirmation, then close the shrine
- F8 outside the shrine: reset the laboratory

## Smoke test

```text
scenes/tests/growth_progression_smoke_test.tscn
```

The smoke test verifies threshold behavior, level rewards, XP rollover, Growth Point spending, and a permanent Vitality increase.
