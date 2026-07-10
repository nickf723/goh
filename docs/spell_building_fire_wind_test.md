# Fire Field and Wind Gust Test

## Goal

Add two spell-sandbox building blocks after Poison Cloud:

- `Fire Field`, a lingering burning hazard.
- `Wind Gust`, a short cone/pulse that pushes enemies.

## Controls

```txt
F9 / F10: cycle scenarios
F6: spawn selected scenario
F7: clear spawned enemies
8: equip Fire Field
9: equip Wind Gust
Q: cast equipped spell
```

## Scenarios

```txt
Fire Field Lab
Wind Gust Lab
Hazard Combo Lab
```

## Expected behavior

### Fire Field

1. Select `Fire Field Lab`.
2. Press `F6`.
3. Press `8` to equip `Fire Field`.
4. Press `Q` while facing enemies.
5. A pulsing orange field appears in front of Grace.
6. Enemies standing inside gain `burning` and take health damage over time.

### Wind Gust

1. Select `Wind Gust Lab`.
2. Press `F6`.
3. Press `9` to equip `Wind Gust`.
4. Face an enemy and press `Q`.
5. A pale blue gust pulses forward.
6. Enemies in front receive an air/force payload and should get pushed.

### Hazard Combo Lab

1. Select `Hazard Combo Lab`.
2. Press `F6`.
3. Cast Poison Cloud or Fire Field near enemies.
4. Use Wind Gust to shove enemies into the lingering hazards.

## Notes

This is not final balance. The important test is whether battlefield spells can create hazards and then move enemies into those hazards.
