# Foundry Sabotage v1 — Manual Playtest

## Player-facing goal

Infiltrate the occupied foundry, disable its power core through one of three physical sabotage routes, then cross the newly unlocked north escape.

Scene:

```text
scenes/levels/prototypes/prototype_foundry_sabotage_v1.tscn
```

## Controls

- MOVE / CAMERA — navigate the foundry.
- LIGHT / HEAVY — use the equipped Training Hammer.
- FOCUS — select Firebolt, Metal Tether, or Gust.
- CAST — use the selected spell.
- REEL IN / REEL OUT — build tension while Metal Tether is attached.
- DODGE — evade the guards.
- RESET — reload the encounter in editor builds.

## Baseline route

1. Enter from the south and read the compact upper-right HUD.
2. Confirm two Gremlin guards remain unaware until they see Grace or hear movement.
3. Cross the smoke curtain. Confirm it obscures the guards' sightline.
4. Cast Gust through the curtain. Confirm visible density moves and guard visibility may change.
5. Complete exactly one sabotage route:
   - **Burned Hoist:** select Firebolt and ignite the wooden hoist coupling.
   - **Masonry Fracture:** use a Heavy Hammer attack on the cracked center column.
   - **Metal Brace Extraction:** attach Metal Tether to the gold brace and build enough tension to pull it free.
6. Confirm the supported crucible, slab, or gantry becomes ordinary falling rigid-body debris.
7. Confirm the collapse produces a dust burst, a loud sound stimulus, and environmental impact damage near the core.
8. Confirm surviving guards investigate or react to the collapse location rather than receiving Grace's hidden current position.
9. Confirm the furnace light cools, the core HUD changes to `OFFLINE`, and the north escape changes to `ESCAPE OPEN`.
10. Cross the blue north exit and confirm the encounter-complete message.

## Alternate-route regression

Reset between attempts and finish the encounter once through each route. Every route must:

- release its supported member;
- disable the same core;
- emit a collapse stimulus;
- unlock the same escape;
- preserve combat, Focus selection, and ordinary player movement.

## Performance check

The smoke curtain contains only `8 × 5 × 7 = 280` possible cells and displays every second cell. Confirm the encounter remains materially smoother than the original Gas Dynamics Laboratory while Gust still redistributes the smoke.

## Known limitations

- Prototype geometry and procedural materials do not imply final foundry art direction.
- Structural collapses use authored support graphs rather than automatic mesh decomposition.
- Collapse damage is a radial gameplay consequence layered over physical debris collision.
- Guards use perception and local movement without a navigation mesh, so large debris can obstruct them.
- The encounter is runtime-only and does not save completion or connect to story progression.
