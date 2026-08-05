# Enemy Personality Laboratory v1 Test

## Goal

Verify the movement-only foundation for the Enemy Personality Laboratory before any personality tuning begins. Four identical production Goblins must acquire four harmless lane targets and traverse identical geometry without player stimulation, attack actions, or damage to Grace.

## Scene

Launch **Enemy Personality Laboratory** from the Development Control Center, or run:

```text
scenes/levels/prototypes/prototype_enemy_personality_lab_v1.tscn
```

## What this version proves

- Every lane uses the shared `goblin_drone.tscn` actor.
- Cautious, Bold, Skittish, and Brute are data assignments, not custom enemy implementations.
- Each harmless target begins inside the Goblin Brawler's natural detection radius.
- The Goblins enter pursuit without Grace approaching, striking, or provoking them.
- Combat is disabled locally by clearing the lab Goblins' default attack resource.
- Grace remains invulnerable and is never selected as a lane target.
- RESET restores authored transforms, health, stance, statuses, force, target assignment, and poison-hazard runtime state.

## Manual playtest

1. Enter the lab and leave Grace at the observation area.
2. Confirm the four lanes are labeled Cautious, Bold, Skittish, and Brute.
3. Confirm every lane contains the same Goblin scene, the same target distance, and the same Poison Bloom placement.
4. Confirm all four Goblins begin moving toward their visible **HARMLESS TARGET** markers without any input from Grace.
5. Watch for several seconds and confirm no Goblin performs a claw windup, active attack, or recovery animation.
6. Confirm Grace's health does not change.
7. Use RESET or F8 and confirm every Goblin snaps back to its exact authored start with zero retained momentum.
8. Confirm the Goblins naturally reacquire their targets and begin moving again after reset.
9. Enable developer vision, if useful, and confirm each overhead readout reports its assigned personality and movement state.

## Automated regression

Run:

```text
godot --headless --path . res://scenes/tests/enemy_personality_lab_smoke_test.tscn
```

The regression verifies:

- all four production Goblins and inert targets exist;
- lane target distances and hazard offsets are identical;
- every target begins inside detection range;
- the intended target remains resolved throughout the run;
- all four Goblins leave IDLE and travel a meaningful distance;
- no attack state or running attack action appears during frame-by-frame observation;
- Grace's health remains unchanged;
- reset restores exact entry state; and
- autonomous movement resumes after reset.

## Expected result

This room should read as a trustworthy behavioral ruler: one production Goblin implementation, four personality profiles, identical circumstances, no combat noise. Route-shape and temperament tuning come only after this baseline remains green.

## Deliberately deferred

- Personality profile retuning.
- New action-selection behavior.
- New navigation architecture.
- Encounter balance or combat challenge.
- Final environment art and presentation polish.
