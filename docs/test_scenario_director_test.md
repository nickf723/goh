# Test Scenario Director v1

## Goal

Verify that the existing development sandbox can cycle, spawn, reset, and clear resource-driven mechanic laboratories.

## Scene

Open:

```text
scenes/levels/_dev/dev_interaction_sandbox.tscn
```

Run Current Scene.

## Controls

```text
F9   next scenario
F10  previous scenario
F6   spawn or reset selected scenario
F7   clear spawned scenario nodes
F12  run development audit
```

The message panel should always show the selected scenario, recommended ability, expected result, and controls.

## Oil + Fire

1. Cycle until `Oil + Fire` is selected.
2. Confirm the objective says `Dev test: Oil + Fire`.
3. Press `F6`.
4. Confirm one Goblin and one oil patch spawn near Grace.
5. Confirm Firebolt becomes the selected spell.
6. Let the Goblin contact the oil patch if needed.
7. Cast Firebolt at the Goblin.
8. Confirm the existing oily + fire reaction produces burning.
9. Press `F6` again and confirm the prior Goblin and oil patch are replaced rather than duplicated.

Expected guidance:

```text
Recommended: Firebolt
Expected: The target gains burning after oil and fire combine.
```

## Wet + Lightning

1. Press `F9` until `Wet + Lightning` is selected.
2. Press `F6`.
3. Confirm the Oil + Fire spawned nodes disappear.
4. Confirm one Goblin and one water patch spawn near Grace.
5. Confirm Lightning Spark becomes the selected spell.
6. Let the Goblin contact the water patch if needed.
7. Cast Lightning Spark at the Goblin.
8. Confirm the existing wet + lightning reaction produces stunned.

Expected guidance:

```text
Recommended: Lightning Spark
Expected: The wet target becomes stunned when lightning connects.
```

## Sound Reveal

1. Press `F9` until `Sound Reveal` is selected.
2. Press `F6`.
3. Confirm the Wet + Lightning spawned nodes disappear.
4. Confirm Sound Pulse becomes the selected spell.
5. Look toward the indicated space in front of Grace. The crystal begins hidden.
6. Cast Sound Pulse toward it.
7. Confirm the existing sound detection payload reveals the crystal.

Expected guidance:

```text
Recommended: Sound Pulse
Expected: The hidden crystal becomes visible when the sound detection pulse reaches it.
```

## Clear and regression

1. Press `F7`.
2. Confirm all scenario-spawned enemies and props disappear.
3. Press `F12` and confirm the existing development audit still runs.
4. Cycle backward with `F10` and confirm the selected scenario wraps correctly.
5. Confirm movement, camera, spell casting, Focus, Dev Vision, and normal sandbox interactables still work.

## Known limitations

- The director guides a human test but does not automatically assert that a reaction succeeded.
- Enemy movement may require a moment before the target enters the spawned surface.
- The selector is developer-only and keyboard-first.
- The three laboratories use existing prototype scenes and visuals.
