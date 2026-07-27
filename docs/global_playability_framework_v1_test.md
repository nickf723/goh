# Global Playability Framework v1 Manual Test

## Scene

```text
scenes/levels/prototypes/prototype_drowned_bell_v1.tscn
```

Use a clean run or restart the scene before testing.

## 1. Guidance route

1. Confirm a blue objective marker identifies Orin.
2. Accept The Drowned Bell.
3. Confirm Orin's marker disappears and the listening-point marker appears.
4. Listen on the causeway.
5. Confirm guidance advances to the chapel entrance.
6. Enter the chapel and confirm three optional-colored clue markers appear.
7. Complete each clue and confirm its marker disappears.
8. Confirm the tuning plate and crypt seal become the next primary markers in sequence.

Pass condition: guidance follows quest state without leaving obsolete markers behind.

## 2. Pool escape

1. Enter the east nave pool without Blink.
2. Swim to the submerged mechanism.
3. Move toward the shallow western steps and leave the water naturally.
4. Re-enter and surface near the west EXIT marker.
5. Press Jump and confirm Grace reaches safe dry ground.
6. Repeat near the rear ledge EXIT marker.
7. Approach the dry recovery ledge and verify it can be climbed as a backup.

Pass condition: Grace can leave the pool through the physical route and both backup exits without entering the void.

## 3. Recovery

1. Walk deliberately along the outer route boundaries.
2. Step or Blink into any remaining floor gap.
3. Fall below the chapel or causeway.
4. Confirm Grace returns to the most recent shore, causeway, or chapel recovery point.
5. Confirm velocity, swimming, climbing, tether, flight, dodge, and lock-on states do not remain stuck after recovery.
6. Confirm brief recovery invulnerability prevents an immediate repeated hit.

Pass condition: no fall lasts indefinitely and recovery does not preserve an unstable locomotion state.

## 4. Safe Blink

Test Blink:

- directly into a wall;
- toward the outside of the playable bounds;
- across the pool edge;
- toward an unsupported gap;
- from ordinary supported ground.

Pass condition: Blink lands on supported clear ground or shortens/fizzles at the last safe candidate. It does not place Grace beyond the authored bounds or inside solid geometry.

## 5. Regression scenes

Boot and briefly traverse:

```text
scenes/levels/prototypes/prototype_broken_waystation_mission_v1.tscn
scenes/levels/prototypes/prototype_ruined_village_approach_v1.tscn
```

Pass condition: the shared recovery controller does not interfere with normal interaction, combat, quest state, or traversal. Falling far below either scene returns Grace to its initial spawn fallback.

## Known limits

- Recovery is a last-resort safety net, not a replacement for authored collision and natural boundaries.
- Swimming exit anchors use a quick safe placement rather than final bespoke climb animation.
- Guidance is world-space and flag-driven; a production compass and accessibility settings remain future presentation work.
- The auditor catches structural contracts, not confusing composition or poor aesthetic quality.
