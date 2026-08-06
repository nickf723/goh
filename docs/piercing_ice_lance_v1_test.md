# Piercing Ice Lance Upgrade Test

## Goal

Verify that the existing progression upgrade still extends the rebuilt physical Ice Lance rather than supplying the spell's entire identity.

```text
Base Ice Lance
    three-target line pierce
    physical force
    surface lodging

Piercing Ice Lance upgrade
    longer target line
    faster travel
    stronger stance pressure
    longer Chill
```

## Current relationship

Ice Lance is no longer a single-target generic projectile. Its base action now uses `ice_lance_projectile.tscn`, forms a full crystalline spear, pierces up to three unique targets, and lodges in hard architecture as temporary solid terrain.

The legacy unlock ID remains:

```text
piercing_ice_lance
```

When that unlock is active, `SpellModifierRegistry` duplicates the Ice Lance payload and adds its upgrade tags. The dedicated lance action consumes the existing projectile modifier contract, raising its runtime hit limit from three to four, ensuring at least 24 m/s travel speed, adding stance pressure, extending Chill, and enlarging impact presentation.

## How to test

1. Open `scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn`.
2. Reset progression so `piercing_ice_lance` is locked.
3. Equip Ice Lance.
4. Cast through an aligned target row.
5. Confirm the base spear can pierce three targets.
6. Unlock `Piercing Ice Lance` from its pedestal or development shortcut.
7. Reset the targets.
8. Cast through four aligned targets.
9. Confirm the upgraded spear can reach the fourth target.
10. Confirm the upgraded cast still uses the long physical lance and can lodge in architecture afterward.
11. Confirm Firebolt, Lightning Spark, and their modifiers remain unchanged.
12. Reset progression and confirm Ice Lance returns to its three-target base capacity.

## Expected feel

The base spell should already feel complete:

```text
PIERCE • DRIVE • EMBED
```

The upgrade should feel like a reinforced lance that retains more authority through a crowded line, not a switch that turns a small bullet into the real spell.

## Known limitations

- The unlock name remains `Piercing Ice Lance` for save and progression compatibility even though the base spell now pierces.
- A future progression migration may rename the display-facing upgrade to `Transfixing Ice Lance` or `Reinforced Ice Lance` while preserving the stable unlock ID.
- Moving-surface inheritance, weapon-driven shattering, Fire melting, and stacked-lance limits remain future work.
