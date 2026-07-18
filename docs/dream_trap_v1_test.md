# Dream Trap v1 test

## Goal

Add the first ground-targeted delayed trigger spell.

```text
equip Dream Trap -> press cast -> move violet marker -> confirm -> enemy enters -> dream burst triggers
```

Dream Trap should reuse the same ground-targeting controller path as Earth Spike, Poison Bloom, and Time Snare, but its effect happens later when an enemy steps into the field.

## Setup

1. Pull branch `agent/dream-trap-v1`.
2. Open `scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn`.
3. Run Current Scene.
4. Press `F8` if you want a clean lab reset.

## Dream Trap placement

1. Equip `Dream Trap` from the spell focus menu.
2. Press cast once.
3. Confirm a violet targeting circle appears on the floor.
4. Move the right stick.
5. Confirm the marker moves instead of rotating the camera.
6. Press cancel / Esc / right click.
7. Confirm the marker disappears and no mana is spent.
8. Enter targeting again.
9. Place the marker in the target lane or in front of a moving enemy.
10. Press cast again.
11. Confirm the violet field appears and waits.

## Trigger behavior

1. Let an enemy enter the field.
2. Confirm a dream burst appears over the target.
3. Confirm the target receives the current `staggered` control status.
4. Confirm the field cleans itself up shortly after triggering.
5. Place another Dream Trap and confirm it expires if nothing triggers it.

## Regression checks

- Earth Spike still uses the brown marker and erupts instantly.
- Poison Bloom still uses the green marker and places a poison cloud.
- Time Snare still uses the gold marker and places a slow field.
- Firebolt and Charged Firebolt still cast normally.
- Ice Lance and Piercing Ice Lance still cast normally.
- Lightning Spark and Chain Lightning still cast normally.

## Known limitations

- Uses `staggered` as the current dream-control carrier.
- Visuals are prototype geometry.
- Mouse-hover placement is not implemented yet.
- This adds another thin caster wrapper for speed. A later registry pass should fold Time Snare and Dream Trap into data-driven ground spell config.
