# Enemy Personality Lab v1 Test

## Goal

Create a controlled room where enemy personality differences are easier to observe than in the mini dungeon.

The room uses four identical Goblin instances. Each lane gives the goblin the same target distance and the same permanent Poison Bloom zone, but a different personality profile:

- Cautious
- Bold
- Skittish
- Brute

## Scene

```text
scenes/levels/prototypes/prototype_enemy_personality_lab_v1.tscn
```

## Setup

Each lane has:

```text
goblin -> poison zone -> invisible lane target
```

The lane target is only bait for the enemy brain. Grace can stand back and watch.

## How to test

1. Pull branch `agent/enemy-personality-lab-v1-2`.
2. Open `scenes/levels/prototypes/prototype_enemy_personality_lab_v1.tscn`.
3. Run Current Scene.
4. Do not move at first. Watch all four lanes from the player start position.
5. Confirm each goblin starts moving toward its lane target.
6. Compare the steering around the green Poison Bloom zone.
7. Confirm `Cautious` respects the zone more than `Bold`.
8. Confirm `Bold` takes a more direct route than `Cautious` or `Skittish`.
9. Confirm `Skittish` shows the widest or most reluctant avoidance.
10. Confirm `Brute` reacts less than cautious/skittish but still reads the zone.
11. Press RESET / F8 to reload and compare again.
12. Enable developer/debug view if available and confirm enemy debug data reports `personality`, `zone`, and `zone_wait`.

## Expected feel

The difference should read as the same basic goblin brain with different tuning knobs:

```text
Skittish = widest detour
Cautious = careful but functional
Bold = closer pass
Brute = least reactive
```

## Known limitations

- This lab uses local steering, not navigation-mesh pathfinding.
- The permanent Poison Bloom zones are test props, not final encounter design.
- The room is deliberately artificial so personality differences are easier to spot.
- If the differences are still too subtle, tune the profile multipliers in `enemy_personality_traits.gd` rather than adding one-off behavior to the lab.
