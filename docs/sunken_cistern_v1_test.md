# The Sunken Cistern - Manual Test

## Scene

```text
scenes/levels/prototypes/sunken_cistern_v1.tscn
```

Standalone `experimental` elemental dungeon. Not wired into canon or progression.
Automated regression:

```text
scenes/tests/sunken_cistern_smoke_test.tscn
```

## Purpose

Validate that Grace can run the Sunken Cistern end to end while the shared spell,
element-lock, ice-bridge, gate, enemy, save, and reward systems stay coherent
under a fresh authored layout.

## What it reuses

- `scripts/puzzles/prototype_element_lock_target.gd` + `prototype_element_lock_controller.gd`
- `scripts/puzzles/village_ice_bridge.gd`
- `scenes/actors/interactables/readable_magic_gate.tscn`, `save_bed.tscn`,
  `mana_shrine.tscn`, `church_trial_reward_altar.tscn`, `level_exit.tscn`,
  `scenes/items/reward_choice_chest.tscn`
- `scenes/actors/enemies/storm_drain_gremlin_actor.tscn`, `large_construct_enemy.tscn`,
  `stoneback_salamander_enemy.tscn`
- Loadout `data/loadouts/sunken_cistern_loadout.tres` (Ice Lance, Lightning Spark,
  Firebolt, Space Blink)

No new mechanics. No `capability_inventory.json` change.

## Core route

1. Start the scene. Confirm Grace spawns with movement, camera, HUD, and the
   four-spell cistern loadout (Ice / Lightning / Fire / Blink) equipped.
2. **Sluice Entry** - use the save bed and mana shrine. Cast **Ice** at the
   running sluice channel; it freezes into a walkable path. Cross it.
3. Cast **Ice** at the `ICE` ward past the crossing. The pump gate opens.
4. **Pump Hall** - two Storm-drain Gremlins engage. Clear them. Use the
   mid-point save bed.
5. Cast **Lightning** at the `LIGHTNING` ward on the dais. The reservoir gate
   opens.
6. *(Optional)* **Overflow Gallery** - through the branch mouth on the right of
   the pump hall. Cast **Fire** at the `FIRE` ward to steam the frost grate; the
   cache gate opens onto a three-choice reward chest.
7. **Cracked Reservoir** - cross the pool via the two stone islands. A Large
   Construct guards the far ledge. Cast **Ice** at one ward and **Lightning** at
   the other; with both lit, the undercroft gate opens.
8. **Drowned Undercroft** - fight the Stoneback Salamander. Interact with the
   reward altar for the cistern seal, then touch the exit.

## Regression checklist

- The four-spell loadout is applied on start and again after a reset.
- Freezing the sluice hardens `BridgeCollision`; the water visual swaps to ice.
- Each ward accepts only its element; the wrong element prints a rejection line.
- A room's gate opens only when every ward in that room is lit; the undercroft
  gate needs both reservoir wards.
- The optional gallery never blocks the main route; skipping it is fine.
- Falling into a pit returns Grace to the last stage's respawn point with a
  message (no death, no reload).
- `restart_scene` (default reset input) re-applies the loadout, refills
  resources, resets the ice bridge, and moves Grace to the entrance.
- Reaching the exit sets the `sunken_cistern_complete` flag and the completion
  objective.

## Known limitations (v1)

- Prototype primitives and `_make_material` only; no final art, audio, or
  animation.
- No literal swim traversal - the flooded look is shallow water sheets plus the
  freeze-crossing. Deep-water swimming is deferred until the Drowned Bell
  swim-clearance work lands.
- The Stoneback Salamander is present but is not a hard gate on the exit.
- `restart_scene` does not re-close gates that were already opened; reload the
  scene for a full reset.
- Enemy encounters are placed, not gated on kills or sequenced.
- The reward altar grants a placeholder key item id (`sunken_cistern_seal`).
