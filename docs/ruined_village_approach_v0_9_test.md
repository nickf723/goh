# Ruined Village Approach v0.9 Manual Test

## Purpose

This is the first integrated outdoor level for **Grace of Humanity**. It should feel like a place in the game rather than a laboratory: exploration, environmental story, weapon combat, elemental problem-solving, optional Sound discovery, checkpointing, and the Church Trial all share one route.

## Load the level

Run:

```text
res://scenes/levels/prototypes/prototype_ruined_village_approach_v1.tscn
```

The expected first objective is:

```text
Survey the impossible village and reach the church above the ruins.
```

## Controller expectations

Use the player's configured actions rather than fixed physical-button labels:

```text
MOVE
INTERACT
LIGHT
HEAVY
FOCUS
CAST
DODGE
LOCK-ON
RESET (editor test only)
```

The level must not alter the user's L/R/ZL/ZR mappings.

## Route overview

```text
Teleport Impact Hollow
        ↓
Abandoned Armory
        ↓
Outer Foundations and Clues
        ↓
Village Square + Optional Sound Memory
        ↓
Goblin / Gremlin Ambush
        ↓
Encounter Barricade Opens
        ↓
Collapsed Ravine
   ↙                    ↘
Water → Ice Bridge      Fire OR Ice + Heavy Debris Route
   ↘                    ↙
Church Hill Stairs
        ↓
Church Grounds Checkpoint
        ↓
Church Trial Entrance
```

## 1. Arrival hollow

- Confirm Grace begins inside the teleport-impact hollow, facing toward the village.
- Confirm the church towers and gold entrance are visible as a distant landmark.
- Inspect the crater clue.
- Confirm its message describes the fused ring and inward-bent grass.
- Equip Sword, Hammer, or Spear from the optional abandoned armory.
- Confirm the racks do not change controller bindings.

## 2. Outer village exploration

- Follow the stepped road into the higher village layer.
- Confirm the area contains foundations, partial houses, a dry well, hearth, cart, trees, and displaced soil edges.
- Inspect the lifted-foundation clue.
- Confirm it suggests that part of the village was removed intact rather than destroyed.
- Inspect the empty-hearth clue.
- Confirm it implies interrupted daily life without explaining the full history.
- Walk the edges and confirm cliffs and terrain boundaries prevent accidental escape from the playable area.

## 3. Optional Sound memory

- Enter the village square without using Sound.
- Find the faint interaction near the hidden relic.
- Confirm interacting before reveal reports that the source remains hidden.
- Select Sound Pulse and cast near the hidden relic.
- Confirm the wooden bird becomes visible with Sound/reveal feedback.
- Interact with it.
- Confirm the optional message references a child's carved wooden bird and does not explain Cirianca outright.
- Confirm the main route remains completable without finding the memory.

## 4. Village square combat

- Enter the square and trigger the encounter.
- Confirm two Goblins and one Gremlin spawn from the registered encounter definition.
- Test Light/Heavy branches with the chosen weapon.
- Use spells and at least one elemental reaction during combat.
- Confirm lock-on sees the active enemies.
- Defeat all three enemies.
- Confirm two Mana are restored.
- Confirm the objective updates to finding a route across the ravine.
- Confirm the broad scavenger barricade lowers after completion.

## 5. Two-solution ravine gate

Test both methods, reloading or using editor RESET between them.

### Fire solution

- Approach the right stone bridge.
- Cast Fire at the root-choked debris.
- Confirm the debris opens immediately and the route becomes traversable.

### Ice and Heavy solution

- Cast Ice at the debris.
- Confirm it turns visibly icy and reports that a forceful strike could shatter it.
- Use a Heavy or force-tagged weapon attack.
- Confirm the debris shatters and the route opens.

The gate must not open from an unrelated light attack while unfrozen.

## 6. Water and Ice bridge

Test this independently from the right route.

- Approach the left side of the ravine.
- Cast Water across the marked crossing.
- Confirm the target receives the Wet state.
- Cast Ice onto the same target.
- Confirm the crossing changes from water to a visible crystalline bridge.
- Walk across and confirm collision is stable.
- Confirm the bridge remains available until the scene resets, prioritizing test reliability over a short expiration timer.

## 7. Church approach

- Confirm both ravine routes converge beneath the church hill.
- Climb the stairs to the third elevation layer.
- Confirm the church facade, two towers, cypress trees, graves, and glowing entrance provide a clear destination.
- Reach the camp/save point.
- Interact and confirm Health, Mana, Stamina, and Stance restore.
- Confirm the save scene path is the Ruined Village Approach.

## 8. Death and checkpoint

- Save at the church-ground camp.
- Take lethal damage or use a controlled debug method.
- Confirm the death retry reloads the current level.
- Confirm Grace returns to the camp position with saved stats, flags, key items, and objective.
- Confirm already completed permanent village flags restore their corresponding route state.

## 9. Church handoff

- Interact with the glowing church entrance.
- Confirm the scene changes to:

```text
res://scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn
```

- Complete a brief Church Trial regression:
  - movement and camera;
  - Light/Heavy combat;
  - spell casting;
  - elemental locks;
  - Sound reveal;
  - save bed;
  - boss startup.

## 10. Development Control Center

- Open the Development Control Center.
- Confirm **Ruined Village Approach** appears before Church Trial.
- Confirm its detail panel identifies it as an integrated story level, version v0.9.
- Confirm dependencies, controls, state policy, manual test path, and limitations come from the registry.
- Launch it directly from the Control Center.

## 11. Automated validation

Run:

```powershell
python scripts/ci/validate_feature_registry.py
python scripts/ci/run_feature_registry.py --godot godot
```

Expected registered village targets:

```text
res://scenes/levels/prototypes/prototype_ruined_village_approach_v1.tscn
res://scenes/tests/ruined_village_approach_smoke_test.tscn
```

The smoke test validates:

- procedural geometry density;
- player and Game UI presence;
- three environmental clues;
- encounter definition integrity;
- Fire route solution;
- Ice + Heavy route solution;
- Water + Ice bridge activation;
- Sound memory reveal;
- checkpoint presence;
- deliberate Church Trial exit path.

## Creative review

Judge the level on these questions:

1. Does the church remain a readable destination without flattening exploration into a straight hallway?
2. Does the village communicate impossible absence rather than ordinary destruction?
3. Do the combat and puzzles feel situated in the environment rather than pasted beside it?
4. Are the two ravine routes meaningfully different and easy to understand?
5. Does the optional Sound memory reward curiosity without blocking progression?
6. Does the 15–25 minute route feel dense rather than cramped or empty?
7. Does reaching the Church Trial feel like a natural escalation?

## Known prototype limitations

- Terrain, ruins, vegetation, props, and church architecture are procedural replacement art.
- The playable footprint is spatially compressed while implying a broader 250 × 350 meter village region.
- Enemies use current Goblin and Gremlin behavior rather than village-specific archetypes.
- The Water/Ice bridge remains latched until reset for dependable prototype testing.
- No voice acting, authored audio, cinematics, imported foliage, navigation mesh, or final lighting pass is included.
- The level deliberately withholds the full explanation of Cirianca and the village's removal.
