# Enemy Personality Laboratory v1 Test

## Goal

Verify that four identical Goblins use the existing cautious, bold, skittish, and brute personality profiles in a controlled comparison room.

## Scene

Launch **Enemy Personality Laboratory** from the Development Control Center, or run:

```text
scenes/levels/prototypes/prototype_enemy_personality_lab_v1.tscn
```

## Manual playtest

1. Enter the lab and remain near the starting position.
2. Confirm the four lanes are labeled Cautious, Bold, Skittish, and Brute.
3. Confirm each lane contains the same Goblin, target distance, and Poison Bloom obstacle.
4. Watch each Goblin move toward its own lane target.
5. Confirm Skittish takes the widest or most reluctant route around the poison.
6. Confirm Cautious avoids the hazard more strongly than Bold.
7. Confirm Bold takes a more direct route than Cautious or Skittish.
8. Confirm Brute reacts least to the trap while still respecting major danger.
9. Use RESET and confirm all four Goblins, hazards, and lane comparisons return to their entry state.
10. Enable developer vision, if desired, and confirm enemy debug data reports `personality`, `zone`, and `zone_wait`.

## Expected result

The room should read as one shared Goblin brain controlled by existing personality data, not four custom enemy implementations.

## Known limitations

- The room is an artificial tuning instrument rather than encounter design.
- It uses local steering rather than navigation-mesh pathfinding.
- Poison Bloom zones and presentation remain prototype assets.
- Final personality feel still requires manual comparison; the smoke test verifies initialization rather than subjective readability.
