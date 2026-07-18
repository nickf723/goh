# Time Snare v1 test

## Goal

Use the ground-targeting framework for a lingering control field.

```text
equip Time Snare -> press cast -> move gold marker -> press cast again -> slow field appears
```

## Setup

1. Pull branch `agent/time-snare-v1`.
2. Open `scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn`.
3. Run Current Scene.
4. Use the spell focus menu to equip `Time Snare`.

## Time Snare placement

1. Press cast once.
2. Confirm a gold targeting circle appears on the ground.
3. Move the right stick.
4. Confirm the marker moves instead of the camera.
5. Move the marker near Grace and away from Grace.
6. Confirm the marker clamps within the normal ground-targeting range.
7. Press cancel / Esc / right click.
8. Confirm the marker disappears and no mana is spent.

## Time Snare confirm

1. Press cast once again to enter placement mode.
2. Move the gold marker over the target lane.
3. Press cast again to confirm.
4. Confirm a flat gold temporal field appears at the marker position.
5. Confirm targets inside the field receive `chill` / slow status.
6. Confirm targets leaving the field recover after a short delay.
7. Confirm the field expires after a few seconds.

## Regression checks

1. Equip Earth Spike.
2. Confirm the brown marker still moves, cancels, and erupts.
3. Equip Poison Bloom.
4. Confirm the green marker still moves, cancels, and places the poison cloud.
5. Confirm Firebolt still casts normally.
6. Confirm Charged Firebolt still charges and fires.
7. Confirm Ice Lance and Piercing Ice Lance still work.
8. Confirm Lightning Spark and Chain Lightning still work.

## Known limitations

- Time Snare currently uses `chill` as the shared slow carrier.
- The field visual is prototype geometry.
- Mouse-hover placement is still not implemented.
- The player scene now uses a thin Time Snare caster wrapper over the ground-targeting caster.
