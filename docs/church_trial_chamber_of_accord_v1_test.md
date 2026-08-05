# Church Trial: Chamber of Accord v1

## Scene

The chamber is a packed production puzzle:

```text
res://scenes/environment/church/church_trial_chamber_of_accord_v1.tscn
```

It is installed into `Room3Puzzle` when the Church Trial launches:

```text
res://scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn
```

## Purpose

Replace the former two-cube Fire/Water lock with the first authored dungeon puzzle built from the shared mechanism grammar. The room combines physical Soul Grip manipulation, measured weight, value comparison, elemental order, memory, final completion latching, world presentation, and save persistence.

## Diegetic clues

The room avoids laboratory state labels. Its authored clues are part of the architecture:

- the left scale is inscribed `V`;
- the right scale is inscribed `II + III`;
- the three Soul-marked offerings carry the runes `II`, `III`, and `V`;
- the altar wall reads `WATER • THEN • FIRE`;
- dormant floor channels illuminate as each requirement is satisfied.

## Manual route

1. Clear the Church Trial combat room and enter the Chamber of Accord.
2. Confirm the passage seal is closed and all three offerings are available near the room entrance.
3. Select Soul Grip in Focus.
4. Place offering `V` on the left scale.
5. Place offerings `II` and `III` together on the right scale.
6. Confirm the brass balance channels illuminate.
7. Cast Fire at the Fire altar before using Water. Confirm the passage remains closed and the rite rejects the order.
8. Cast Water at the Water altar. Confirm the blue channel illuminates and the objective asks for Fire.
9. Remove one offering before casting Fire. Confirm the unfinished elemental attempt clears.
10. Restore `V = II + III`.
11. Cast Water, then Fire.
12. Confirm the central seal lights, the passage gate rises, and the objective advances toward the echo passage.
13. Remove all offerings after completion. Confirm the gate remains open.
14. Continue through the existing Sound transition, boss save bed, Animated Armor fight, reward altar, and final exit.

## Save persistence

After solving the chamber:

1. Continue to the Armor Trial bed and save.
2. Leave to the title and use Continue.
3. Confirm the Chamber of Accord passage is already open.
4. Confirm offering positions, scale loads, and unfinished elemental sequence state were not persisted.

Only this story flag is durable:

```text
church_trial_chamber_of_accord_complete
```

Physical object placement, supported mass, altar pulses, and partial Water/Fire progress remain runtime state.

## Fresh reset

In the editor, F8 clears the Church Trial prototype save through the existing director and reloads the scene.

Expected fresh state:

- completion flag false;
- all three offerings returned to their authored positions;
- both scales empty;
- Water/Fire sequence at step zero;
- central seal dormant;
- passage gate closed.

## Automated regression

Run:

```text
godot --headless --path . res://scenes/tests/church_trial_chamber_of_accord_smoke_test.tscn
```

The regression verifies:

- packed-scene instantiation;
- three Soul-Grippable offerings;
- empty scale startup;
- unequal and equal scale behavior;
- Fire-first rejection;
- Water progress;
- balance-loss sequence reset;
- Water-then-Fire completion;
- completion latching after offerings move;
- story-flag restoration in a fresh room instance;
- explicit fresh reset;
- replacement of the legacy lock cubes at runtime; and
- preservation of the Sound transition, boss, save bed, reward altar, and final exit.

## Known limitations

- Geometry, materials, runes, channel lighting, and altar presentation remain replacement-ready procedural assets.
- The scale clue is intentionally direct for the first production integration pass.
- Soul Grip still uses its shared yaw-oriented object rotation controls.
- Final audio, particles, Church-specific animation, and accessibility clue alternatives are not represented.
