# Drowned Chapel Environment v2.2 Manual Test

Scene:

```text
scenes/levels/prototypes/prototype_drowned_bell_v1.tscn
```

## Purpose

Confirm that the existing Drowned Bell quest now takes place in one coherent authored prototype space rather than disconnected test slabs. This pass adds no new quest stage or mechanic.

## Route test

1. Begin at the marsh road and speak with Orin.
2. Accept the investigation and walk the complete causeway without jumping.
3. Use the listening point and enter the chapel.
4. From the doorway, confirm that the bell frame, west memorial aisle, flooded east chapel, altar, and crypt are all readable as distinct landmarks.
5. Inspect the memorial plaque and severed rope.
6. Enter the flooded side chapel, inspect the burial mechanism, and leave through the broad stair exit.
7. Re-enter the pool and leave through the rear broken-ledge exit.
8. Recover the tuning plate and reach the crypt seal.

## Environment checks

- The causeway should feel continuous even though its surface stones are visually broken up.
- The chapel should read as a vestibule, nave, memorial aisle, flooded side chapel, altar, and crypt.
- Pillars, pews, and debris should frame routes without snagging Grace.
- The bell should hang in a timber frame rather than appearing as a freestanding cylinder.
- The rose window and altar should establish the far end of the room from the entrance.
- The pool surface and swimming volume should align visually.
- The main pool stairs should work without assisted snapping.
- The rear exit should remain available as a second physical route.
- Current ribbons should make the water push legible.
- Giant environment labels should no longer carry the composition.

## Deliberate abuse pass

- Walk along both edges of the causeway.
- Press against every outer chapel wall and doorway corner.
- Circle every pillar and pew with the camera close behind Grace.
- Enter the pool from the front, side, and rear.
- Try to leave the pool while facing away from both exits.
- Blink toward the pool rim, outer walls, broken rafters, and beyond the causeway.
- Fall beneath the chapel if a gap can be found and confirm global recovery remains a backup.

## Acceptance

The pass is successful when the full route is understandable and traversable without relying on Blink, Flight, recovery, or developer instructions. Safety recovery may catch deliberate abuse, but ordinary play should not trigger it.

Automated coverage:

```text
scenes/tests/drowned_bell_environment_smoke_test.tscn
scenes/tests/global_playability_framework_smoke_test.tscn
scenes/tests/drowned_bell_foundation_smoke_test.tscn
```
